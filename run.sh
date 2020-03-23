#
#   Static site exporter
#   Optimized for simple wordpress (elementor built)
#   sites with minimal list of plugins use
#

STATIC_SITE_SOURCE_DOMAIN="localhost:8007"
STATIC_SITE_TARGET_DOMAIN="screenshot-tracker.nomadinteractive.co"

STATIC_SITE_SOURCE="http://$STATIC_SITE_SOURCE_DOMAIN/"
STATIC_SITE_TARGET="http://$STATIC_SITE_TARGET_DOMAIN/"


function additional_downloads {
	# additional downloads (that httrack can't download)
	# srcsets in img tags, css fonts, js local resources...

	echo "---> Checking additonal downloads for the file $1"

	for u in $(grep -vEo '^/\*' $1 | grep -Eo "$STATIC_SITE_SOURCE[^\"') ]+")
	do
		# echo $u
		
		# get plain filename
		local filename=$(basename $u | cut -d '#' -f 1 | cut -d '?' -f 1)
		
		# get extension and define target folder
		local ext=$(echo $filename | cut -d '.' -f 2)
		if [ "$ext" = "js" ] || [ "$ext" = "css" ] || [ "$ext" = "png" ] || [ "$ext" = "jpg" ]; then
			local targetFolderName="$ext"
		else
			local targetFolderName="assets"
		fi
		local targetFolder="./docs/$targetFolderName"
		local targetFile="$targetFolder/$filename"

		# create target folder (by file extension) if not exists
		if ! test -d $targetFolder ; then
			mkdir $targetFolder
		fi
		
		# downloading the file
		echo "--> Downloading $u to $targetFile"
		curl -s $u > $targetFile

		# replace the url with the new relative path in the source file
		sed -i '' -e "s~$u~$2$targetFolderName/$filename~g" $1

	done
}


# Clean up previously generated static site
rm -rf ./docs

#
#   httrack - to export the wordpress site
#
#   with options:
#   -I0     do not create log index file
#   -N1004  HTML in root, images/other in web/xxx,
#           where xxx is the file extension
#           (i.e: all gif -> web/gif)
#

httrack $STATIC_SITE_SOURCE \
	-O ./docs \
	--urllist urllist.txt \
	--do-not-log \
	--verbose \
	-I0 \
	-N1004


# clean up httrack cache
if test -d ./docs/hts-cache; then
	rm -r ./docs/hts-cache
fi

# inex.html was httrack log index, rename actual index
if test -f ./docs/index-2.html; then
	mv ./docs/index-2.html ./docs/index.html
fi

# html source changes..
for f in ./docs/*.html
do

	# Lines clean up
	sed -i '' -e 's/<!--.*-->//' $f
	sed -i '' -e "/link rel=\"canonical\"/d" $f
	sed -i '' -e "/link rel=\"alternate\"/d" $f
	sed -i '' -e "/rel.*https:\/\/api.w.org\//d" $f
	sed -i '' -e "/var elementorFrontendConfig/d" $f
	sed -i '' -e "/var ElementorProFrontendConfig/d" $f
	sed -i '' -e "s/src='.*frontend.min.js'//g" $f

	# perform additional downloads
	additional_downloads $f

	# Replace all remaining original site urls to target
	sed -i '' -e "s~$STATIC_SITE_SOURCE_DOMAIN~$STATIC_SITE_TARGET_DOMAIN~g" $f

done

# do additional downloads in css files
for f in ./docs/css/*.*
do
	additional_downloads $f '../'
done

# # do additional downloads in js files
for f in ./docs/js/*.*
do
	additional_downloads $f '../'
done
