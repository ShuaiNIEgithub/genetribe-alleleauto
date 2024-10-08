#!/usr/bin/env bash

#     genetribe - core.sh
#     Copyright (C) Yongming Chen
#     Contact: chen_yongming@126.com
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

set -e

if [ -z "$1" ]; then
        echo "The arguments is empty!"
        exit 1
fi

gettime() {
	echo -e `date '+%Y-%m-%d %H:%M:%S ... '`
}

dont_stat_chromosome_group=""
stat_confidence=""
count_collinearity=""

Usage () {
	echo ""
	echo "Tool:  GeneTribe core"
        echo "Usage: genetribe core -l <FirstName> -f <SecondName> [options]"
	echo ""
        echo "Description:"
        echo "  Core workflow of GeneTribe"
	echo ""
        echo "Options:"
        echo "  -h         Show this message and exit"
        echo "  -l <str>   Prefix name of first file"
        echo "  -f <str>   Prefix name of second file"
	echo "  -d <dir>   Pre-computed BLAST file in <dir> [default ./]"
	echo "  -r         Calculate chromosome group score [default True] "
	echo "                If not considering the same chromosome groups, add this parameter"
	echo "  -c         Calculate confidence score [default False]"
	echo "                If considering annotation quality, add this parameter."
	echo "  -s <str>   The string for spliting gene from transcript ID [default .]"
	echo "  -e         E-value of BLASTP [default 1e-5]"
	echo "  -n <int>   Number of threads for blast [default 36]"
	echo "  -b <float> BSR-based threshold for filtering Homology Match Score (0-100) [default 75]"
	echo "  -m         Using collinearity as weight [default True]"
	echo "                If not considering collinaerity, add this parameter"
	echo ""
	echo "Author: Yongming Chen; chen_yongming@126.com"
	echo ""
	exit 1
}
while getopts "hl:f:d:rcs:e:n:b:m" opt
do
    case $opt in
        h)
                Usage
                exit 1
                ;;
        l)
                aname=$OPTARG
                ;;
        f)
                bname=$OPTARG
                ;;
	d)
		directory=$OPTARG
		;;
	r)
		dont_stat_chromosome_group="-r"
		;;
	c)
		stat_confidence="-c"
		;;
	s)
		fa_str=$OPTARG
		;;
	e)
		evalue=$OPTARG
		;;
	n)
		num_threads=$OPTARG
		;;
	b)
		score_threshold=$OPTARG
		;;
	m)
		count_collinearity="-m"
		;;
        ?)
                echo "Unknow argument!"
                exit 1
                ;;
        esac
done
#
dec=`echo $(dirname $(readlink -f "$0")) | sed 's/src/bin/g'`

logo () {
	echo ""
	echo "   ==============================="
	echo "  ||                             ||"
	echo "  ||         GeneTribe           ||"
	echo "  ||       Version: v1.2.1       ||"
	echo "  ||                             ||"
	echo "   ==============================="
	echo ""
}
logo

echo `gettime`"prepare files..."

${dec}/coredetectFileExist \
	-d ${directory-./} \
	-a ${aname} \
	-b ${bname} \
	-e ${evalue-1e-5} \
	-n ${num_threads-36} \
	-f ${fa_str-.} \

${dec}/corelns \
	-a ${aname} \
	-b ${bname}

cd ./genetribe_output

if [ "$aname"x = "$bname"x ];then
	bname=${aname}itself
fi

#===
echo `gettime`"calculate BSR, CBS and Penalty..."

for key in ${aname}__${bname} ${bname}__${aname};do

	array=(${key//__/ })
        array=${array[@]}
        key1=`echo $array | gawk '{print $1}'`
        key2=`echo $array | gawk '{print $2}'`
	keynew=${key1}_${key2}
	${dec}/coreCalculateScore \
                -i ${keynew}.blast2 \
                -m ${keynew}.matchlist \
                -a ${key1}.bed \
                -b ${key2}.bed \
                --oa ${key1}_${key1}.blast2 \
                --ob ${key2}_${key2}.blast2 \
                ${dont_stat_chromosome_group} \
		${stat_confidence} \
		-o ${keynew}.chrinfo > ${keynew}.score1

	echo ""
	python -m jcvi.compara.catalog ortholog --no_strip_names ${key1} ${key2}
	echo ""

	${dec}/coreCBS -i ${key1}.${key2}.lifted.anchors -a ${key1}.bed -b ${key2}.bed -o ${keynew}

	${dec}/coreCollinearityBlockDirection -i ${keynew}.collinearity_info -a ${key1}.bed -b ${key2}.bed -o ${keynew}

	${dec}/coreMergeScore -i ${keynew}.score1 -c ${keynew}.block_pos -a ${key1}.bed -b ${key2}.bed > ${keynew}.score2

done

#===
${dec}/coreScore2one -a ${aname}_${bname}.score2 -b ${bname}_${aname}.score2 > ${aname}_${bname}.score

cat ${aname}_${bname}.score | gawk -vOFS='\t' '{print $2,$1,$3,$4,$5}' > ${bname}_${aname}.score

#===
if [ ${count_collinearity}x = ""x ];then
	
	echo `gettime`"evaluate optimal α for weighting score..."
	
	chr11=`sed -n '1p' ${aname}_${bname}.matchlist | gawk -vFS=',' '{print $1}'`
	chr22=`sed -n '2p' ${aname}_${bname}.matchlist | gawk -vFS=',' '{print $1}'`
	
	${dec}/coreSplitbyChromosomeGroup \
		-i ${aname}_${bname}.score \
		-l ${aname}.bed \
		-f ${bname}.bed \
		-m ${chr11},${chr22} \
		-t ${aname}_${bname}.chrinfo > ${aname}_${bname}_chr11xchr22.score
	${dec}/coreSplitbyChromosomeGroup \
		-i ${bname}_${aname}.score \
		-l ${bname}.bed \
		-f ${aname}.bed \
		-m ${chr22},${chr11} \
		-t ${bname}_${aname}.chrinfo > ${bname}_${aname}_chr22xchr11.score
	
	for value in 0 5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 99;do
	
		${dec}/coreSetWeight -i ${aname}_${bname}_chr11xchr22.score -a ${value} -f ${score_threshold-75} \
			> ${aname}_${bname}_chr11xchr22.weighted_score
	
		${dec}/coreSetWeight -i ${bname}_${aname}_chr22xchr11.score -a ${value} -f ${score_threshold-75} \
			> ${bname}_${aname}_chr22xchr11.weighted_score
	
		totalnum=`cat ${aname}.bed | wc -l`
	
		${dec}/RBH -a ${aname}_${bname}_chr11xchr22.weighted_score -b ${bname}_${aname}_chr22xchr11.weighted_score \
			> ${aname}_${bname}_chr11xchr22.BMP
	
		wc -l ${aname}_${bname}_chr11xchr22.BMP | \
			cut -d" " -f1 | gawk -v bmpvalue=${value} -v total=${totalnum} -vOFS='\t' '{print bmpvalue,$1/total,$1,total}' >> ${aname}_${bname}_chr11xchr22.stat
	
	done
	
	max_percent=`sort -k2nr ${aname}_${bname}_chr11xchr22.stat | sed -n '1p' | cut -f1`

	echo `gettime`"α = "${max_percent}"..."
else
	max_percent=0
fi

#===
echo `gettime`"merge raw score..."
${dec}/coreSetWeight -i ${aname}_${bname}.score \
        -a ${max_percent} \
	-f ${score_threshold-75} \
	> ${aname}_${bname}.weighted_score

${dec}/coreSetWeight -i ${bname}_${aname}.score \
        -a ${max_percent} \
	-f ${score_threshold-75} \
	> ${bname}_${aname}.weighted_score


#===
echo `gettime`"process all chromosome pairs..."
Numberofrounds=1

for firstchr in `sed -n '1p' ${aname}_${bname}.matchlist | sed 's/,/ /g'`;do
for secondchr in `sed -n '2p' ${aname}_${bname}.matchlist | sed 's/,/ /g'`;do

	echo `gettime`"number of rounds: "${Numberofrounds}" ..."
	Numberofrounds=$((Numberofrounds+1))

	${dec}/coreSplitbyChromosomeGroup \
		-i ${aname}_${bname}.weighted_score \
		-l ${aname}.bed \
		-f ${bname}.bed \
		-m ${firstchr},${secondchr} \
		-t ${aname}_${bname}.chrinfo > ${aname}_${bname}_${firstchr}x${secondchr}.weighted_score
	${dec}/coreSplitbyChromosomeGroup \
		-i ${bname}_${aname}.weighted_score \
		-l ${bname}.bed \
		-f ${aname}.bed \
		-m ${secondchr},${firstchr} \
		-t ${bname}_${aname}.chrinfo > ${bname}_${aname}_${secondchr}x${firstchr}.weighted_score

	${dec}/RBH -a ${aname}_${bname}_${firstchr}x${secondchr}.weighted_score -b ${bname}_${aname}_${secondchr}x${firstchr}.weighted_score \
		> ${aname}_${bname}_${firstchr}x${secondchr}.BMP

	${dec}/coreSingleSideBest -a ${aname}_${bname}_${firstchr}x${secondchr}.weighted_score \
		-b ${aname}_${bname}_${firstchr}x${secondchr}.BMP \
		> ${aname}_${bname}_${firstchr}x${secondchr}.single_end

	#
	cat ${aname}_${bname}_${firstchr}x${secondchr}.BMP | \
		gawk -vOFS='\t' '{print $2,$1}' > ${bname}_${aname}_${secondchr}x${firstchr}.BMP

	${dec}/coreSingleSideBest -a ${bname}_${aname}_${secondchr}x${firstchr}.weighted_score \
		-b ${bname}_${aname}_${secondchr}x${firstchr}.BMP \
		> ${bname}_${aname}_${secondchr}x${firstchr}.single_end

	cat ${aname}_${bname}_${firstchr}x${secondchr}.BMP | sort | uniq | \
		gawk -vOFS='\t' -vgroup=${secondchr} '{print $1,$2,group}' >> ${aname}_${bname}.BMP

	cat ${bname}_${aname}_${secondchr}x${firstchr}.BMP | sort | uniq | \
		gawk -vOFS='\t' -vgroup=${firstchr} '{print $1,$2,group}' >> ${bname}_${aname}.BMP

	#
	cat ${aname}_${bname}_${firstchr}x${secondchr}.single_end | sort | \
		uniq | gawk -vOFS='\t' -vgroup=${secondchr} '{print $1,$2,group}' \
		>> ${aname}_${bname}.single_end

	cat ${bname}_${aname}_${secondchr}x${firstchr}.single_end | sort | \
		uniq | gawk -vOFS='\t' -vgroup=${firstchr} '{print $1,$2,group}' \
		>> ${bname}_${aname}.single_end

done
done

#===
echo `gettime`"merge results..."

for key in ${aname}__${bname} ${bname}__${aname};do

	array=(${key//__/ })
	array=${array[@]}
	key1=`echo $array | gawk '{print $1}'`
	key2=`echo $array | gawk '{print $2}'`
	keynew=${key1}_${key2}

	cat ${keynew}.BMP | gawk -vOFS='\t' '{print $1,$2,"RBH",$3}' > ${keynew}.raw_total
	cat ${keynew}.single_end | gawk -vOFS='\t' '{print $1,$2,"SBH",$3}' >> ${keynew}.raw_total

	${dec}/coreCorrectTotal -i ${keynew}.raw_total -t ${keynew}.chrinfo -b ${key2}.bed > ${keynew}.raw_total2

	${dec}/corermTwoType -i ${keynew}.raw_total2 > ${keynew}.raw_total3

	${dec}/corebestUnGene -i ${keynew}.raw_total3 -t ${keynew}.chrinfo \
		-c ${keynew}.weighted_score -b ${key1}.bed > ${keynew}.total

	${dec}/coreSingleton -a ${key1}.bed -b ${keynew}.total > ${keynew}.singleton

done

#===
#mv *.pdf ../
cd ..

cat ${aname}_${bname}.one2one | gawk -vOFS="\t" '{if($3=="RBH")print}' > ${aname}_${bname}.RBH
cat ${aname}_${bname}.one2one | gawk -vOFS="\t" '{if($3=="SBH")print}' > ${aname}_${bname}.SBH
cat ${bname}_${aname}.one2one | gawk -vOFS="\t" '{if($3=="SBH")print}' > ${bname}_${aname}.SBH

rm -rf genetribe_output
echo `gettime`"done!"
