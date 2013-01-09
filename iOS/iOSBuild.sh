#!/bin/sh

CURDIR=$(pwd)
BUILDDIR=$CURDIR/../../Build

# $1 will always be the --prefix=... arg
# we assume that the prefix is ALSO the install dir of other libs

# $2 is the action (release, debug, clean)

PREFIX=$(echo $1 | perl -pe 's:\x13::g' -) #Strip hexa characters added by XCode
CONFIGURATION=$(echo $2 | perl -pe 's:\x13::g' | tr [:upper:] [:lower:])

echo "Building lib with prefix : <"$PREFIX">"
echo "And target : <"$CONFIGURATION">"

# If any arg is missing, return
if [ -z $PREFIX ] || [ -z $CONFIGURATION ]; then
	echo "Missing args !"
	exit 1
fi

# If arg 2 is clean, run cleanup, delete installed files (if any) and return
if [ "xclean" = "x$CONFIGURATION" ]; then
	cd $BUILDDIR
	./cleanup
	cd $CURDIR
	cd $PREFIX
	LIBS=$(find ./lib -name 'libarcommands*')
	for LIBFILE in $LIBS; do
		rm -f $LIBFILE
	done
	if [ -d ./include/libARCommands/ ]; then
		rm -r ./include/libARCommands/
	fi
	exit 0
fi

# Setup configure args
CONF_ARGS="--prefix=$PREFIX --with-libSalInstall=$PREFIX CC=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/llvm-gcc --host=arm-apple CFLAGS="
CONF_CFLAGS="-arch armv7 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS6.0.sdk"

# Add debug flag if needed
if [ "xdebug" = "x$CONFIGURATION" ]; then
	CONF_DEBUG=" --enable-debug"
else
	CONF_DEBUG=""
fi

cd $BUILDDIR
# If configure file does not exist, run bootstrap
if [ ! -f configure ]; then
	./bootstrap || exit 1
fi

# If config.log or Makefile does not exist, run configure
if [ ! -f config.log ] || [ ! -f Makefile ]; then
	CSCRIPT=./tmp_cfscript.sh
	echo "#!/bin/sh
	./configure $CONF_ARGS\"$CONF_CFLAGS\"$CONF_DEBUG" > $CSCRIPT
	chmod +x $CSCRIPT
	./$CSCRIPT || exit 1
	rm $CSCRIPT
else # config.log exist, check if args were good
	PREV_CONF_ARGS=$(cat config.log | grep "\$ \./configure" | sed 's:[\ \t]*$[\ \t]*\./configure ::')
	STRIP_CONF_ARGS=$(echo "$CONF_ARGS""$CONF_CFLAGS""$CONF_DEBUG" | sed 's:"::g')
	echo $PREV_CONF_ARGS
	echo $STRIP_CONF_ARGS
    # Rerun configure if previous args were not good
	if [ "$STRIP_CONF_ARGS" != "$PREV_CONF_ARGS" ]; then
		CSCRIPT=./tmp_cfscript.sh
		echo "#!/bin/sh
	./configure $CONF_ARGS\"$CONF_CFLAGS\"$CONF_DEBUG" > $CSCRIPT
		chmod +x $CSCRIPT
		./$CSCRIPT || exit 1
	    rm $CSCRIPT
	fi
fi

if [ -f Makefile ]; then
	make || exit 1
	make install || exit 1 
fi

cd $CURDIR
exit 0
