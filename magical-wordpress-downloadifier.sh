#!/bin/bash

# This is provided AS IS. No warranty of any kind.

# A script to sync your remote server
# with your local setup 

function show_help {
    echo
    echo "Usage: magical-wordpress-downloadifier.sh -df -c </path/to/config>" 
    echo
    echo "Syncs a WordPress server to a local instance"
    echo
    echo " -d Include the database"
    echo " -f Include all of the uploads"
    echo " -c The config file to read from"
    echo
}

DATABASE=false
FILES=false
CONFIG=false
while getopts "h?dfc:" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    d)  DATABASE=true
        ;;        
    f)  FILES=true
        ;;        
    c)  CONFIG=$OPTARG
        ;;
    esac
done

if [[ $CONFIG == false ]];then 
	show_help
	echo 
	echo "Config file required"
	exit 1
fi


# Resolve symlinks
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  ROOT="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$ROOT/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
ROOT="$( cd -P "$( dirname "$SOURCE" )" && pwd )"


echo $ROOT
exit 

## END OF USER VARIABLES ##

# Zip up the files
ssh $remote << EOF
	cd $uploadPath
	zip -r $year.zip $year
	ls -lah
EOF
# Download them
scp $remote:$uploadPath/$year.zip ~/Downloads/$year.zip
# Clean up after ourselves
ssh $remote rm $uploadPath/$year.zip
# Move the zip file to your local install
mv ~/Downloads/$year.zip "$localPath/$year.zip"
# Move to the local directory
cd "$localPath"
# Unzip the files
unzip $year.zip
# Do a dump of the remote database and download it 
ssh $remote -C -o CompressionLevel=9 mysqldump -u $remoteU --password=$remotePW --add-drop-table $remoteDB > ~/Downloads/$remoteDB.sql

# Install the database locally
mysql -u $localU --password=$localPW $localDB < ~/Downloads/$remoteDB.sql
# Replace all references to remote images and files to the local ones instead (assumes database prefix of wp)
mysql -v -t -u $localU --password=$localPW <<QUERY_INPUT
		UPDATE \`$localDB\`.\`wp_posts\` SET post_content = REPLACE(post_content, 'http://$remoteURL', 'http://$localURL');
		SELECT ROW_COUNT();
		UPDATE \`$localDB\`.\`wp_options\` SET option_value = REPLACE(option_value, 'http://$remoteURL', 'http://$localURL');
		SELECT ROW_COUNT();		
		UPDATE \`$localDB\`.\`wp_postmeta\` SET meta_value = REPLACE(meta_value, 'http://$remoteURL', 'http://$localURL');
		SELECT ROW_COUNT();		
QUERY_INPUT
