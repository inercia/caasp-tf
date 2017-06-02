#!/bin/sh

OUT_DIR=${OUT_DIR:-.}

echo ">>> Saving images..."
for image in $@ ; do
	filename="$OUT_DIR/docker-image-$(echo $image | tr "/" "_" | tr ":" "_").tar"

	if [ -f "$filename.gz" ] ; then
		echo "$filename.gz already exists"
	else
		echo ">>> Pulling $image"
		docker pull "$image"
		if [ $? -ne 0 ] ; then
			echo "!!! WARNING: could NOT pull $image !!!"
			echo "(this could be a deliberatedly inexistent image)"
			continue
		fi

		[ -d "$OUT_DIR" ] || mkdir -p "$OUT_DIR"

		echo ">>> Saving $image as $filename"
		docker save -o "$filename" "$image"
		[ -f "$filename" ] || { echo "FATAL: aborting..." ; exit 1 ; }

		echo ">>> Compressing $filename"
		gzip "$filename"
	fi
done
