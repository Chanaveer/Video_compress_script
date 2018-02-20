#!/bin/bash

# Copyright 2017 Chanaveer Kadapatti

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# DESCRIPTION
# This script compresses videos of certain resolutions to lower acceptable bitrates, so as to reduce space required to save these videos.
# The target bitrate is ok for human viewing. The script can stopped or aborted and restarted anytime. When restarted, the script will go -
# through the input list of source video files & skip the ones that have already been compressed. It will continue with the first uncompressed file.
#
# REQUIREMENTS
# Unix Bash environment, ffmpeg.
#
# VIDEO RESOLUTIONS SUPPORTED
# (1280 x 720) -> Files with bitrate > 7mbps will be compressed to 6mbps video & 96k audio
# (1920 x 1080) -> Files with bitrate > 10mbps will be compressed to 9mbps video & 96k audio
# (3840 x 2160) -> Files with bitrate > 22mbps will be compressed to 20mbps video & 96k audio
# Files with any other resolutions will be skipped
#
# INPUT PARAMETERS
# File with list videos files needing to be compressed. Each line should have full path to the video file.
#
# OUTPUT
# Converted file. Source file will be overwritten with the compressed file of same name.
# This script also creates a CSV file 'AnalysisResult-VideoConversion.csv' in the folder where this script is placed. Each input video file name is -
# copied to the CSV along with following details:
#
# <Full path of video file>,<Video Width in pixels>,<Video Height in pixels>,<Original bitrate>,<Whether successfully compressed/skipped/Errored along -
# with error detail>

#exit if ffmpeg is not installed
ffmpeg -version > /dev/null

if (( $? != 0 ))
then
	echo "could not find ffmpeg, exiting."; exit 1
fi	

#initialize Analysis Result file
AnalysisResultFileName=AnalysisResult-VideoConversion.csv

if [ -e $AnalysisResultFileName ];then $(rm -f $AnalysisResultFileName);fi;
$(touch $AnalysisResultFileName)
echo "File Name,Width,Height,Bit Rate,Processed" > $AnalysisResultFileName

exec 3<&0
exec 0<$1

#loop through all videos in input file and process them one by one. add results to AnalysisResult.txt
while read nextVideo 
do

	#Initialize line for this video to go into Analysis Result file
	FileReport=""

	#Find Bit Rate, Width, Height of video file	
	BitRate=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 -loglevel quiet "$nextVideo")
	if [ $? -eq 0 ]
	then
		Height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 -loglevel quiet "$nextVideo")
		if [ $? -eq 0 ]
		then
#			Width=$(ffprobe -v error -select_streams v:0 -show_entries -loglevel quiet stream=width -of default=noprint_wrappers=1:nokey=1 "$nextVideo")
			Width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 -loglevel quiet "$nextVideo")
			if [ $? -eq 0 ]; then
				FileReport+=$nextVideo","$Width","$Height","$BitRate
			else
				FileReport+=$nextVideo",Error,"$Height","$BitRate",Error reading Width"
				echo $FileReport >> $AnalysisResultFileName
				continue
			fi;		
		else
			FileReport+=$nextVideo",,Error,"$BitRate",Error reading Height"
			echo $FileReport >> $AnalysisResultFileName
			continue
		fi;
	else
		FileReport+=$nextVideo",,,Error,Error reading Bit Rate"
		echo $FileReport >> $AnalysisResultFileName
		continue
	fi;	
	
	#Successfully found Bit Rate, Width, Height. Continue processing video file.
	#Append -converted text to video file name
	OutputFileName=${nextVideo%%.mp4}
	OutputFileName+="-converted.mp4"

	#convert 720p video
	if (( $Width == 1280 )) && (( $Height == 720 )) && (($BitRate > 7000000));
	then
		echo "Begin converting $nextVideo ($Width x $Height, BitRate:$BitRate) to 6mbps..." 
		ffmpeg -y -i "$nextVideo" -b:v 6000k -b:a 96k -nostats -loglevel 0 -strict -2 "$OutputFileName" < /dev/null

		#check ffmpeg return code - success or not
		if [ $? -eq 0 ]
		then	
			cp -f "$OutputFileName" "$nextVideo"	
			rm -f "$OutputFileName"
			echo "Done converting above file."
			FileReport+=",Yes"
		else
			echo "ERROR converting file. Code="$?
			FileReport+=",Error"
		fi;
		
		echo $FileReport >> $AnalysisResultFileName	

	#convert 1080p video	
	elif (( $Width == 1920 )) && (( $Height == 1080 )) && (($BitRate > 10000000))
	then
		echo "Begin converting $nextVideo ($Width x $Height, BitRate:$BitRate) to 9mbps..." 
		ffmpeg -y -i "$nextVideo" -b:v 9000k -b:a 96k -nostats -loglevel 0 -strict -2 "$OutputFileName" < /dev/null

		#check ffmpeg return code - success or not
		if [ $? -eq 0 ]
		then	
			cp -f "$OutputFileName" "$nextVideo"	
			rm -f "$OutputFileName"
			echo "Done converting above file."
			FileReport+=",Yes"
		else
			echo "ERROR converting file. Code="$?
			FileReport+=",Error"
		fi;
		
		echo $FileReport >> $AnalysisResultFileName	

	#convert 4k video	
	elif (( $Width == 3840 )) && (( $Height == 2160 )) && (($BitRate > 22000000))
	then
		echo "Begin converting $nextVideo ($Width x $Height, BitRate:$BitRate) to 20mbps..." 
		ffmpeg -y -i "$nextVideo" -b:v 20000k -b:a 96k -nostats -loglevel 0 -strict -2 "$OutputFileName" < /dev/null

		#check ffmpeg return code - success or not
		if [ $? -eq 0 ]
		then	
			cp -f "$OutputFileName" "$nextVideo"	
			rm -f "$OutputFileName"
			echo "Done converting above file."
			FileReport+=",Yes"
		else
			echo "ERROR converting file. Code="$?
			FileReport+=",Error"
		fi;
		
		echo $FileReport >> $AnalysisResultFileName	

	else
		echo "Skipping file $nextVideo ($Width x $Height, BitRate:$BitRate)."
		FileReport+=",Skipped - Did not match Height or Width or BitRate"
		echo $FileReport >> $AnalysisResultFileName	
	fi;

done

exec 0<&3
