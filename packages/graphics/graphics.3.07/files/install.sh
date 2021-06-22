#!/bin/sh

VERSION=`ocamlopt -version 2>/dev/null || ocamlc -version`
VERSION=`echo $VERSION | sed -e 's/[+.]//g'`

# $1 is either build or install
if test "$1" = 'build' ; then
  # $2 = 'true' or 'false' (ocaml:preinstalled)
  # $3 = value of ocaml:lib
  # $4 = value of ocaml:share
  # $5 = value of _:share
  # $6 = value of make
  # $7 = 'allopt' or ''

  # Determine if the graphics library was installed with OCaml.
  # This is extremely delicate, as if the this package is being reinstalled then
  # the presence of graphics files could because of *this* package's previous
  # build.

  STATE="$5/state"

  if test -e "$STATE" ; then
    STATE="`cat $STATE`"
  else
    STATE=built
    if test -e "`ocamlopt -where 2>/dev/null || ocamlc -where`/graphics.cmi" ; then
      # Graphics library already installed
      # This rather dirty inspection of the switch state deals with previous
      # versions of this package which didn't write the state file
      CHANGES="$OPAM_SWITCH_PREFIX/.opam-switch/install/graphics.changes"
      if ! test -e "$CHANGES" || \
         ! grep -F graphics.cm "$CHANGES" >/dev/null ; then
        # And it wasn't installed by this package
        STATE=preinstalled
      fi
    fi
  fi

  echo "$STATE" > state

  if test "$STATE" = 'preinstalled' ; then
    exit 0
  fi

  # For system compilers, use the real OCaml LIBDIR, otherwise use the opam one
  if $2 ; then
    OCAML_LIBDIR="`ocamlopt -where 2>/dev/null || ocamlc -where`"
  else
    OCAML_LIBDIR="$3"
  fi

  # Configure the source tree
  if test $VERSION -ge 3090 ; then
    if test $VERSION -ge 4040 ; then
      # reconfigure target introduced in 4.04.0
      if test $VERSION -ge 4080 ; then
        # config/Makefile became Makefile.config in 4.08.0
        cp "$OCAML_LIBDIR/Makefile.config" Makefile.config
        # Makefile.common is now generated in 4.08.0+
        touch Makefile.common
      else
        cp "$OCAML_LIBDIR/Makefile.config" config/Makefile
      fi
      if test -e "$4/config.cache" ; then
        grep -Fv ac_cv_have_x "$4/config.cache" > config.cache
      fi
      $6 reconfigure
    else
      # Otherwise, execute the first line from Makefile.config (which includes
      # the arguments used)
      `sed -ne '1s/# generated by //p' "$OCAML_LIBDIR/Makefile.config"`
    fi
  else
    # Prior to OCaml 3.09.0, config/Makefile wasn't installed, so we just have
    # to make a buest guess
    ./configure -libdir "$OCAML_LIBDIR"
  fi

  # Build the library
  $6 -C otherlibs/graph CAMLC=ocamlc CAMLOPT=ocamlopt MKLIB=ocamlmklib all $7

  # System compilers must always have META installed; this package is a depopt
  # of ocamlfind, so it will be reinstalled if this package is added.
  if $2 ; then
    echo 'lib: ["META"]' >> graphics.install
  fi
elif test -e otherlibs/graph/graphics.cmi ; then
  # $2 = 'true' or 'false' (ocaml:preinstalled)
  # $3 = value of make
  # $4 = value of _:lib
  # $5 = value of stublibs
  # $6 = 'installopt' or ''

  # Installation variables in the Makefile altered with 4.02.0
  if test $VERSION -ge 4020 ; then
    K_LIBDIR=INSTALL_LIBDIR
    K_STUBLIBDIR=INSTALL_STUBLIBDIR
  else
    K_LIBDIR=LIBDIR
    K_STUBLIBDIR=STUBLIBDIR
  fi

  if $2 ; then
    mkdir -p "$4"
    mkdir -p "$5"
    $3 "$K_LIBDIR=$4" "$K_STUBLIBDIR=$5" -C otherlibs/graph install $6
  else
    $3 -C otherlibs/graph install $6
  fi
fi
