#!/usr/bin/env bash

while true ; do
	case "$1" in
		-c|--clear-cache) CLEAR_CACHE=1 ; shift ;;
		--) shift ; break ;;
		*) shift ; break ;;
	esac
done

RESULTCODE=0

# Download the CLI install script to cli
echo "Installing dotnet CLI"
mkdir -p cli
curl -o cli/dotnet-install.sh -L https://dot.net/v1/dotnet-install.sh

if [ $? -ne 0 ]; then
	echo "Could not download 'dotnet-install.sh' script. Please check your network and try again!"
	exit 1
fi

# Run install.sh for cli
chmod +x cli/dotnet-install.sh

# Get recommended version for bootstrapping testing version
cli/dotnet-install.sh -i cli -c 1.0

if [ $? -ne 0 ]; then
	echo ".NET CLI Install failed!!"
	exit 1
fi

DOTNET="$(pwd)/cli/dotnet"
echo "Using dotnet cli from '$DOTNET'"

# Let the dotnet cli expand and decompress first if it's a first-run
$DOTNET --version

# Get CLI Branches for testing
echo "dotnet msbuild build/config.props -v:m -nologo -t:GetCliBranchForTesting"

IFS=$'\n'
CMD_OUT_LINES=(`$DOTNET msbuild build/config.props -v:m -nologo -t:GetCliBranchForTesting`)
# Take the line just before the last empty line and remove all the spaces
DOTNET_BRANCHES=${CMD_OUT_LINES[-1]//[[:space:]]}
unset IFS

IFS=$';'
DOTNET_BRANCHES=(`echo ${CMD_OUT_LINES[-1]}`)
DOTNET_BRANCH=(${DOTNET_BRANCHES[0]})
unset IFS

IFS=$':'
Channel=${DOTNET_BRANCH[0]}
unset IFS

echo $DOTNET_BRANCH
cli/dotnet-install.sh -i cli -c $Channel

# Display current version
$DOTNET --version
$DOTNET --info

echo "================="

# init the repo
git submodule init
git submodule update

# clear caches
if [ "$CLEAR_CACHE" == "1" ]
then
	echo "Clearing the nuget web cache folder"
	rm -rf ~/.local/share/NuGet/*

	echo "Clearing the nuget packages folder"
	rm -rf ~/.nuget/packages/*
fi

# restore packages
echo "dotnet msbuild build/build.proj -t:Restore -p:VisualStudioVersion=16.0 -p:Configuration=Release -p:BuildNumber=1 -p:ReleaseLabel=beta"
$DOTNET msbuild build/build.proj -t:Restore -p:VisualStudioVersion=16.0 -p:Configuration=Release -p:BuildNumber=1 -p:ReleaseLabel=beta

if [ $? -ne 0 ]; then
	echo "Restore failed!!"
	exit 1
fi

# run tests
echo "dotnet msbuild build/build.proj -t:CoreUnitTests -p:VisualStudioVersion=16.0 -p:Configuration=Release -p:BuildNumber=1 -p:ReleaseLabel=beta"
$DOTNET msbuild build/build.proj -t:CoreUnitTests -p:VisualStudioVersion=16.0 -p:Configuration=Release -p:BuildNumber=1 -p:ReleaseLabel=beta

if [ $? -ne 0 ]; then
	echo "Tests failed!!"
	exit 1
fi

exit $RESULTCODE
