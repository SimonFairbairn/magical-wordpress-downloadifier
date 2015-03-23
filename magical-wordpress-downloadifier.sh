#!/bin/bash

# This is provided AS IS. Make sure that all of the variables are set right. 
# If you break anything, it's on you.

# A script to sync your remote server
# with your local setup 

# Your SSH login
remote=user@111.222.333.444 
# Your remote db name
remoteDB=dbname
# Your remote db username
remoteU=dbuser
# Your remote db password
remotePW=dbpassword

# Your local DB
localDB=dbname
# Your local DB Username
localU=dbuser
# Your local DB password
localPW=dbpassword

# Remote URL
remoteURL=www.example.com
# Local URL 
localURL=example.local

# Full to your remote uploads folder (no trailing slash)
uploadPath=/home/user/public_html/wp-content/uploads

# Full path to your local uploads folder (no trailing slash)
localPath="~/Sites/wp-content/uploads"

# The year of uploads. To save time, I only download the current year's uploads, but you can specify "all"
# to download everything in the WordPress uploads folder.
year=2015

## END OF USER VARIABLES ##
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
