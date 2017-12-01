#!/bin/bash

# broken with libsane-hpaio 3.13.4-1+b1
# Dependencies: ps2pdf imagemagick

scan_dir="/tmp/scan/"
ordered_dir=$scan_dir"ordered/"
unordered_dir=$scan_dir"unordered/"
scanner="hp5590"
counter=1
scan_file_name="scan_"
list_files_concatenate=""
final_file=$scan_dir"output"
x_y_Flatbet="-x 208 -y 296"
x_y_ADF="-x 208 -y 302"

clear
echo "resolution? 1-100 2-200: "
select q in "1" "2"; do
    case $q in
        1 ) resolution="100";break;;
        2 ) resolution="200";break;;
    esac
done

echo "mode? 1-Color 2-Gray 3-Lineart : "
select q in "1" "2" "3"; do
    case $q in
        1 ) mode="Color";break;;
        2 ) mode="Gray";break;;
        3 ) mode="Lineart";break;;
    esac
done

echo "source? 1-Flatbet 2-ADF 3-ADF Duplex : "
select q in "1" "2" "3"; do
    case $q in
        1 ) source="Flatbet";opts=$x_y_Flatbet;break;;
        2 ) source="ADF";opts="-b "$x_y_ADF;break;;
        3 ) source="ADF Duplex";opts="-b "$x_y_ADF;break;;
    esac
done

string=`scanimage -L | grep $scanner | cut -d " " -f2`
device=${string/\`/}
device=${device/\'/}

rm -fr $scan_dir
mkdir $scan_dir
mkdir $ordered_dir
 
# start of the slow part
if [[ $source == "Flatbet" ]]
then
    cd $ordered_dir
    scanimage -d "$device" -p --mode $mode --source "$source" --resolution $resolution $opts > out1.pnm
    list_files_concatenate="out1.pnm"
else
    mkdir $unordered_dir
    cd $unordered_dir
    # ADF
    scanimage -d "$device" -p --mode $mode --source "$source" --resolution $resolution $opts
    number_files=`ls $unordered_dir | grep -c pnm`

    # bug: 200+ resolution | Gray | ADF Duplex -> it scans 1 extra page
    if [[ "$resolution" -gt 100 && "$mode" == "Gray" && "$source" == "ADF Duplex" ]]
    then
        # remove the extra page
        rm -fr out"$number_files".pnm
    fi

    # loop over scanned files (out1.pnm out2.pnm etc...)
    for f in $unordered_dir*
    do
        file=`basename $f`
        basename=`echo $file | cut -d '.' -f1`
        number=`echo $basename | cut -d 't' -f2`

        # 0 padding when 10+ pages
        if [[ "$number" -lt 10 && "$number_files" -ge 10 ]]
        then
            number="0"$number
        fi
        cp $file $ordered_dir$number"out.pnm"
    done

    cd $ordered_dir
    # loop to rotate 180 degrees pair pages
    for f in $ordered_dir*
    do
        file=`basename $f`

        if [ `expr $counter % 2` -eq 0 ] && [ "ADF Duplex" == "$source" ]
        then 
            # pair
	    convert -rotate 180 $file $scan_file_name$file
        else
            # odd
            mv $file $scan_file_name$file
        fi
        list_files_concatenate=$list_files_concatenate" "$scan_file_name$file

        counter=`expr $counter + 1`
        #rm -fr $file
    done
fi

convert -density $resolution $list_files_concatenate $final_file".ps"
ps2pdf $final_file".ps" $final_file".pdf"
