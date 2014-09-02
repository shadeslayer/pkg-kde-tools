#! /bin/bash

podir=${podir:-$PWD/po}
files=`find . -name XmlMessages.sh`
dirs=`for i in $files; do echo \`dirname $i\`; done | sort -u`
tmpname="$PWD/messages.log"
INTLTOOL_EXTRACT=${INTLTOOL_EXTRACT:-intltool-extract}
INTLTOOL_FLAGS=-q
test -z "$VERBOSE" || INTLTOOL_FLAGS=
XGETTEXT=${XGETTEXT:-xgettext}
# using xgettext 0.15 or later
### TODO what --flags param should be used?
XGETTEXT_FLAGS="--copyright-holder=This_file_is_part_of_KDE --from-code=UTF-8 -C --kde --msgid-bugs-address=http://bugs.kde.org"
export INTLTOOL_EXTRACT XGETTEXT XGETTEXT_FLAGS

for subdir in $dirs; do
  test -z "$VERBOSE" || echo "Making XML messages in $subdir"
  (cd $subdir

   if test -f XmlMessages.sh; then
     xml_po_list=`bash -c ". XmlMessages.sh ; get_files"`
     for xml_file_relpath in $xml_po_list; do
       xml_file_po=`bash -c ". XmlMessages.sh ; po_for_file $xml_file_relpath"`
       xml_podir=${xml_file_relpath}.podir
       xml_in_file=$xml_podir/`basename $xml_file_relpath`.in
       if [ ! -e $xml_podir ]; then
         mkdir $xml_podir
         cat $xml_file_relpath | sed -e 's/.*lang=.*//g' | sed -r -e 's/(\<\/?)comment(\>)/\1_comment\2/g' > $xml_in_file
         if test -s $xml_in_file ; then
           $INTLTOOL_EXTRACT $INTLTOOL_FLAGS --type='gettext/xml' $xml_in_file
           $XGETTEXT $XGETTEXT_FLAGS --keyword=N_ -o $podir/${xml_file_po}t ${xml_in_file}.h
         else
           echo "Empty preprocessed XML file: $xml_in_file !"
         fi
         rm -rf $xml_podir
       else
         echo "$xml_podir exists!"
       fi
     done
   fi
   exit_code=$?
   if test "$exit_code" -ne 0; then
       echo "Bash exit code: $exit_code"
   else
       rm -f rc.cpp
   fi
   ) >& $tmpname
   test -s $tmpname && { echo $subdir ; cat "$tmpname"; }
done

rm -f $tmpname
