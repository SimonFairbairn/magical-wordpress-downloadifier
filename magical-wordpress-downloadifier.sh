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
    echo " -d Download and update the database"
	echo " -u Just update the database"
    echo " -f Include downloading uploads"
    echo " -c The config file to read from"
	echo " -y The year of photos to download"
    echo
}

DATABASE=false
UPDATE=false
FILES=false
CONFIG=false
OPTYEAR=false
while getopts "h?dufc:y:" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    d)  DATABASE=true
        ;;
	u)  UPDATE=true
		;;
    f)  FILES=true
        ;;
	y)  OPTYEAR=$OPTARG
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

source $CONFIG

if [[ $OPTYEAR != false ]]; then
	year=$OPTYEAR
fi

if [[ ! -n $remote ]]; then
	echo "ERROR: Remote server not found in config file"
	exit 1
else
	echo "Config file found and loaded"
fi


function getFiles {

	file=$year
	if [ $year == "all" ]
	then
		echo "Downloading all files"
		file="."
	fi

# Zip up the files
ssh $remote << EOF
	cd $uploadPath
	zip -r $year.zip $file
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
}

function downloadDatabase {
	# Do a dump of the remote database and download it
	ssh $remote -C -o CompressionLevel=9 mysqldump -u $remoteU --password=$remotePW --add-drop-table $remoteDB > ~/Downloads/$remoteDB.sql
	# Install the database locally
	mysql -u $localU --password=$localPW $localDB < ~/Downloads/$remoteDB.sql

}

function updateDatabase {
	# Replace all references to remote images and files to the local ones instead (assumes database prefix of wp)
mysql -v -t -u $localU --password=$localPW <<QUERY_INPUT
		UPDATE \`$localDB\`.\`wp_posts\` SET post_content = REPLACE(post_content, 'http://$remoteURL', '$localURL');
		SELECT ROW_COUNT();
		UPDATE \`$localDB\`.\`wp_posts\` SET post_content = REPLACE(post_content, 'https://$remoteURL', '$localURL');
		SELECT ROW_COUNT();
		UPDATE \`$localDB\`.\`wp_options\` SET option_value = REPLACE(option_value, 'http://$remoteURL', '$localURL') WHERE option_name='siteurl';
		SELECT ROW_COUNT();
		UPDATE \`$localDB\`.\`wp_options\` SET option_value = REPLACE(option_value, 'http://$remoteURL', '$localURL') WHERE option_name='home';
		SELECT ROW_COUNT();
		UPDATE \`$localDB\`.\`wp_options\` SET option_value = REPLACE(option_value, 'https://$remoteURL', '$localURL') WHERE option_name='siteurl';
		SELECT ROW_COUNT();
		UPDATE \`$localDB\`.\`wp_options\` SET option_value = REPLACE(option_value, 'https://$remoteURL', '$localURL') WHERE option_name='home';
		SELECT ROW_COUNT();
QUERY_INPUT

		# UPDATE \`$localDB\`.\`wp_postmeta\` SET meta_value = REPLACE(meta_value, 'http://$remoteURL', 'http://$localURL') ;
		# SELECT ROW_COUNT();

}

if [[ "$FILES" == true ]]; then
	getFiles
else
	echo "Skipping file transfer..."
fi


if [[ "$DATABASE" == true ]]; then
	downloadDatabase
	updateDatabase
else
	echo "Skipping database transfer..."
fi

if [[ "$UPDATE" == true && "$DATABASE" == false ]]; then
	updateDatabase
else
	echo "Skipping database transfer..."
fi
