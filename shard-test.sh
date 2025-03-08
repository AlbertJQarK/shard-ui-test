#!/bin/bash

# STF VARS
TOKEN_STF=$(cat ~/.env-sft | grep "TOKEN_STF" | cut -d '=' -f 2)
STF_HOST=$(cat ~/.env-stf | grep "STF_HOST" | cut -d '=' -f 2)

#MAX_DEVICE_NUMBER=1

# PROJECT VARS
flavor=""
variant="debug"

# TAG LIST FOR MONITORING RESULTS
errors_tag_list=("^Tests run: *[0-9]*,  Failures: *[0-9]*" "Process crashed" "INSTRUMENTATION_FAILED")
success_tag_list=("^OK (*[0-9]* test")

current_folder=$(pwd)
base_path=$(if [ "${1}" != "" ];then echo "${1}"; else echo "${current_folder}"; fi)
log_folder="$base_path/app/build/outputs/logs"
test_runner=$(cat $base_path/app/build.gradle | grep "TestRunner" | cut -d '"' -f 2 | cut -d '.' -f 5)
test_app_id=$(cat $base_path/app/build.gradle | grep "testApplicationId" | cut -d '"' -f 2)
test_runner_path=$(echo $test_app_id | sed -e "s/\./\//g")
test_tags=$(cat $base_path/app/src/androidTest/java/$test_runner_path/$test_runner.kt | grep "tags" | tr ',' '\n' | grep "@" | grep -v "Cucumber" | sed -e "s/\"//g" | sed -e "s/\[//g" | sed -e "s/(//g" | sed -e "s/\]//g" | sed -e "s/)//g" | sed -e "s/ //g" | sed -e "s/=//g" | sed -e "s/tags//g" | tr '\n' ', ')
IFS=', ' read -r -a test_tags_array <<< "$test_tags"
number_of_tests=$(grep -r -o -f <(printf "%s\n" "${test_tags_array[@]}") $base_path/app/src/androidTest | grep -v ".kt" | wc -l | sed -e "s/ //g")

name=$(cd $base_path; git config --local remote.origin.url | sed -n 's#.*/\([^.]*\)\.git#\1#p')
git_branch=$(cd $base_path; git status | grep branch | grep On | awk {'print $3'})

# Regular Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
ENDCOLOR='\033[0m'

# Styles
BOLD='\033[1m'
NORMAL='\033[0m'

# Emojis
emoji_list=(🔥 🍁 👻 👾 🎃 🥷 👑 🐰 🦊 🐼 🐨 🐷 🐸 🦋 🐌 🦀 🐡 🐠 🐳 🦢 🦮 🐢 🐙 🐓 🌵 🍀 🍄 🌸 🌼 🌏 🌊 🍋 🍌 🍉 🍓 🍒 🥥 🥝 🥑 🧀 🍿 🍺)
emoji_raw=${emoji_list[RANDOM%${#emoji_list[@]} + 1]}
emoji=$(echo "$emoji_raw" | tr -d '[:space:]')

function displaytime {
  local T=$1
  local D=$((T/60/60/24))
  local H=$((T/60/60%24))
  local M=$((T/60%60))
  local S=$((T%60))
  (( $D > 0 )) && printf '%d days ' $D
  (( $H > 0 )) && printf '%d hours ' $H
  (( $M > 0 )) && printf '%d minutes ' $M
  (( $D > 0 || $H > 0 || $M > 0 )) && printf 'and '
  printf '%d seconds\n' $S
}

function ProgressBar {
  barName=${1}
  # Process data
  let _progress=(${2}*100/${3}*100)/100
  let _done=(${_progress}*5/2)/10
  let _left=25-$_done
  # Build progressbar string lengths
  _fill=$(printf "%${_done}s")
  _empty=$(printf "%${_left}s")

  printf "\r${barName}[${_fill// /#}${_empty// /-}] ${_progress}%%"
}

function check_push_progress(){
     re='^[0-9]+$'
     local push_to=$1 #path in the device
     local push_from=$2 #path to local file
     local device=$3 #device to connect
     local current=0
     local complete=1
     echo "pushing $push_from to $push_to"
     init=0
     while [ $current -ne $complete ]; do
        adb_command=$(adb -s $device shell ls -l $push_to)
        current=$(echo $adb_command | awk '{print $5}')
        if ! [[ $current =~ $re ]] ;then
            current=0
        fi

        if [ "$current" != "0" ]; then
           if [ "$init" == "0" ]; then
              init=1
           fi
        fi

        complete_command=$(ls -l $push_from)
        complete=$(echo $complete_command | awk '{print $5}')
        if [ "$init" == "1" ]; then
            if [ "$current" == "0" ]; then
              current=$complete
            fi
        fi
        pcomplete=$((100*$current/$complete))
        echo $pcomplete
        sleep 2
    done
}

function complete_banner {
  line=${1}
  end_line=${2}
  line_length=${#line}
  counter=$line_length
  while [ $counter -lt $end_line ];do
    line+=" "
    counter=$((counter+1))
  done
  line+="##"
  echo "$line"
}

function printBanner() {
  start=`date +%s`

  lmachine=$(complete_banner "   ##$GREEN$BOLD Machine:$ENDCOLOR $NORMAL$BOLD$HOSTNAME$NORMAL" 107)
  lproject=$(complete_banner "   ##$GREEN$BOLD Project:$ENDCOLOR $NORMAL$BOLD$name$NORMAL" 107)
  lflavor=$(complete_banner "   ##$GREEN$BOLD Flavor:$ENDCOLOR $NORMAL$BOLD$flavor$NORMAL" 107)
  lvariant=$(complete_banner "   ##$GREEN$BOLD Variant:$ENDCOLOR $NORMAL$BOLD$variant$NORMAL" 107)
  lbranch=$(complete_banner "   ##$GREEN$BOLD Branch:$ENDCOLOR $NORMAL$BOLD$git_branch$NORMAL" 107)
  ltest_app_id=$(complete_banner "   ##$GREEN$BOLD Test App ID:$ENDCOLOR $NORMAL$BOLD$test_app_id$NORMAL" 107)
  ltest_runner=$(complete_banner "   ##$GREEN$BOLD Runner:$ENDCOLOR $NORMAL$BOLD$test_runner$NORMAL" 107)
  lnumber_of_tests=$(complete_banner "   ##$GREEN$BOLD Number of tests:$ENDCOLOR $NORMAL$BOLD$number_of_tests$NORMAL" 107)
  ldevices=$(complete_banner "   ##$GREEN$BOLD Devices:$ENDCOLOR $NORMAL$BOLD$number_of_devices$NORMAL" 107)

  mkdir -p $log_folder
  echo -e ""
  echo -e "   #############################################################"
  echo -e "   ## $BOLD ALBERTJ                                    $emoji       $NORMAL   ##"
  echo -e "   ## $BLUE █████   ███    ██ ██████  ██████   ██████  ██ ██████$ENDCOLOR   ##"
  echo -e "   ## $BLUE ██   ██ ████   ██ ██   ██ ██   ██ ██    ██ ██ ██   ██$ENDCOLOR  ##"
  echo -e "   ## $BLUE ███████ ██ ██  ██ ██   ██ ██████  ██    ██ ██ ██   ██$ENDCOLOR  ##"
  echo -e "   ## $BLUE ██   ██ ██  ██ ██ ██   ██ ██   ██ ██    ██ ██ ██   ██$ENDCOLOR  ##"
  echo -e "   ## $BLUE ██   ██ ██   ████ ██████  ██   ██  ██████  ██ ██████$ENDCOLOR   ##"
  echo -e "   ## $BOLD Testing Assistance Tool                             $NORMAL   ##"
  echo -e "   #############################################################"
  echo -e "$lmachine"
  echo -e "$lproject"
  echo -e "$lflavor"
  echo -e "$lvariant"
  echo -e "$lbranch"
  echo -e "$ltest_app_id"
  echo -e "$ltest_runner"
  echo -e "$lnumber_of_tests"
  echo -e "$ldevices"
  counter=0
  for ip in "${ips_array[@]}";do
    if [[ "${status_array[$counter]}" == *"device"* ]];then
      status_color=$GREEN
    else
      status_color=$RED
    fi
    ldevice=$(complete_banner "   ##$GREEN$BOLD Device $counter:$ENDCOLOR $NORMAL$BOLD$ip:${ports_array[$counter]} $status_color${status_array[$counter]}$ENDCOLOR$NORMAL"  124)
    echo -e "$ldevice"
    counter=$((counter+1))
  done
  echo "   #############################################################"
}

function printExecutionTime {
  color=${1}
  end=`date +%s`
  runtime=$((end-start))
  echo -e "   #############################################################"
  echo -e " $color $BOLD Total execution time: $(displaytime ${runtime}) $emoji $NORMAL $ENDCOLOR"
  echo ""
}

# GET DEVICES ARRAY
function getDeviceArray {
  devices=$($ANDROID_HOME/platform-tools/adb devices)

  #IPS
  device_ips=$(echo "$devices" | grep -v "offline" | grep -v "unauthorized" | grep ":"  | cut -d ':' -f 1 | tr '\n' ',')
  IFS=', ' read -r -a ips_array <<< "$device_ips"

  #PORTS
  device_ports=$(echo "$devices" | grep -v "offline" | grep -v "unauthorized" | grep -o "[0-9]*" | grep -E '(^|[^0-9])[0-9]{4}($|[^0-9])' | tr '\n' ',')
  IFS=', ' read -r -a ports_array <<< "$device_ports"

  #STATUS
  device_status=$(echo "$devices" | grep -v "offline" | grep -v "unauthorized" | grep ":" | cut -d ':' -f 2 | sed 's/[0-9]//g' | sed 's/\t//g' | tr '\n' ',')
  IFS=', ' read -r -a status_array <<< "$device_status"

  number_of_devices=${#ips_array[@]}
  if [ "${number_of_devices}" == "0" ];then
    echo "No devices connected"
    #disconnectDevices
    exit 0
  fi
}

# BUILD APP APK
function buildApk() {
  barName="   ## 🛠${BOLD} Building app         $NORMAL  "
  max_tasks=500
  log_file="$log_folder/${flavor}${variant}ApkBuild.log"
  ProgressBar "$barName" 0 $max_tasks

  cd $base_path
  command="./gradlew app:assemble${flavor}${variant}"
  $command > $log_file 2>&1 &

  exit=1
  while [ ${exit} -gt 0 ];do

    tasks_done=$(cat $log_file | grep "Task" | wc -l)
    ProgressBar "$barName" $tasks_done $max_tasks

    build_failed=$(cat $log_file | grep "BUILD FAILED")
    if [ "${build_failed}" != "" ];then
      ProgressBar "$barName" $max_tasks $max_tasks
      onBuildError "$barName"
    fi

    build_success=$(cat $log_file | grep "BUILD SUCCESSFUL")
    if [ "${build_success}" != "" ];then
      ProgressBar "$barName" $max_tasks $max_tasks
      exit=0
    fi
    sleep 2
  done
  echo ""
}

function onBuildError {
  barName="${1}"
  echo -e "\r$barName[#########${RED}${BOLD}FAILED${NORMAL}${ENDCOLOR}##########] 100%"
  echo ""
  printExecutionTime $RED
  disconnectDevices
  exit 0
}

# BUILD INSTRUMENTATION TEST
function buildInstrumentationTest() {
  barName="   ## 🛠${BOLD} Building test apps    $NORMAL "

  ndevices=$(echo "${#ports_array[@]}")
  task_per_device=500
  max_tasks=$(($task_per_device*$ndevices))
  ProgressBar "$barName" 0 $max_tasks

  counter=0
  total_tasks_done=0
  for port in "${ports_array[@]}";do
    log_file="$log_folder/shard${counter}Build.log"

    export "ANDROID_SERIAL=${ips_array[$counter]}:$port"
    command="$base_path/gradlew app:assemble${flavor}${variant}AndroidTest -Pandroid.testInstrumentationRunnerArguments.numShards=$number_of_devices -Pandroid.testInstrumentationRunnerArguments.shardIndex=$counter"
    $command > $log_file 2>&1 &

    exit=1
    while [ ${exit} -gt 0 ];do

      tasks_done=$(cat $log_file | grep "Task" | wc -l)
      show_tasks_done=$(($counter*$task_per_device+$tasks_done))
      ProgressBar "$barName" $show_tasks_done $max_tasks

      build_failed=$(cat $log_file | grep "BUILD FAILED")
      if [ "${build_failed}" != "" ];then
        ProgressBar "$barName" $max_tasks $max_tasks
        onBuildError "$barName"
      fi

      build_success=$(cat $log_file | grep "BUILD SUCCESSFUL")
      if [ "${build_success}" != "" ];then
        exit=0
      fi
      sleep 2
    done

    if [ "${flavor}" != "" ];then
      cp $base_path/app/build/outputs/apk/androidTest/${flavor}/${variant}/app-${flavor}-${variant}-androidTest.apk $base_path/app/build/outputs/apk/androidTest/${flavor}/${variant}/app-${flavor}-${variant}-androidTest${counter}.apk
    else
      cp $base_path/app/build/outputs/apk/androidTest/${variant}/app-${variant}-androidTest.apk $base_path/app/build/outputs/apk/androidTest/${variant}/app-${variant}-androidTest${counter}.apk
    fi

    counter=$((counter+1))
    if [ "${counter}" -eq "${ndevices}" ];then
      ProgressBar "$barName" $max_tasks $max_tasks
    fi
  done
  echo ""
}

# INSTALL APP
function installApp() {
  barName="   ## 📲$BOLD Installing app       $NORMAL  "
  ndevices=$(echo "${#ports_array[@]}")
  max_tasks=$((100*$ndevices))

  if [ "${flavor}" != "" ];then
    apk=$(ls $base_path/app/build/outputs/apk/${flavor}/${variant}/*.apk)
    apk_file_name=$(echo ${apk##*/})
    apk_file="$base_path/app/build/outputs/apk/${flavor}/${variant}/$apk_file_name"
  else
    apk=$(ls $base_path/app/build/outputs/apk/${variant}/*.apk)
    apk_file_name=$(echo ${apk##*/})
    apk_file="$base_path/app/build/outputs/apk/${variant}/$apk_file_name"
  fi
  apk_file_name=$(echo ${apk_file##*/})

  counter=0
  for port in "${ports_array[@]}";do
    device="${ips_array[$counter]}:$port"
    export "ANDROID_SERIAL=$device"

    command_pre="adb -s $device shell rm /data/local/tmp/$apk_file_name"
    $commnad_pre > $log_folder/shard${counter}RemoveApp.log 2>&1

    command="adb -s $device install -r $apk_file"
    $command > $log_folder/shard${counter}InstallApp.log 2>&1 &

    percentage_log_file="$log_folder/shardPercentage${counter}InstallApp.log"
    rm -f $percentage_log_file
    check_push_progress "/data/local/tmp/$apk_file_name" "$apk_file" $device > $percentage_log_file 2>&1 &

    exit=1
    while [ "$exit" != "0" ];do

      percentage=$(cat $percentage_log_file | tail -n 1)
      re='^[0-9]+$'
      if ! [[ $percentage =~ $re ]] ; then
        percentage=0
      fi

      show_percentage=$(($counter*100+$percentage))
      ProgressBar "$barName" $show_percentage $max_tasks
      if [ "${percentage}" == "100" ];then
        exit=0
      fi
      sleep 2
    done
    counter=$((counter+1))
  done
  echo ""
}

# INSTALL INSTRUMENTATION TEST
function installInstrumentationTest() {
  barName="   ## 📲$BOLD Installing tests apps  $NORMAL"
  ndevices=$(echo "${#ports_array[@]}")
  ProgressBar "$barName" 0 $ndevices
  counter=0
  for port in "${ports_array[@]}";do
    export "ANDROID_SERIAL=${ips_array[$counter]}:$port"
    if [ "${flavor}" != "" ];then
      command="adb -s ${ips_array[$counter]}:$port install -r $base_path/app/build/outputs/apk/androidTest/${flavor}/${variant}/app-${flavor}-${variant}-androidTest${counter}.apk"
    else
      command="adb -s ${ips_array[$counter]}:$port install -r $base_path/app/build/outputs/apk/androidTest/${variant}/app-${variant}-androidTest${counter}.apk"
    fi
    $command > $log_folder/shard${counter}InstallInstrumentation.log 2>&1
    counter=$((counter+1))
    ProgressBar "$barName" $counter $ndevices
  done
  echo ""
}

# LAUNCH INSTRUMENTATION TEST USING ADB
function launchInstrumentationTestADB() {
  barName="   ## 📡$BOLD launching tests      $NORMAL  "
  ndevices=$(echo "${#ports_array[@]}")
  ProgressBar "$barName" 0 $ndevices
  counter=0
  for port in "${ports_array[@]}";do
    export "ANDROID_SERIAL=${ips_array[$counter]}:$port"
    command_pre="shell am instrument -w -m --no-window-animation -e package regression -e debug false -e numShards $number_of_devices -e shardIndex"
    command_post="$test_app_id/$test_app_id.$test_runner"
    command="adb -s ${ips_array[$counter]}:$port $command_pre $counter $command_post"
    $command > $log_folder/shard${counter}Instrumentation.log 2>&1 &
    counter=$((counter+1))
    ProgressBar "$barName" $counter $ndevices
  done
  echo ""
}

# MONITOR INSTRUMENTATION TEST
function monitoringInstrumentationTest() {
  barName="   ## 🚀$BOLD Executing tests       $NORMAL "
  ProgressBar "$barName" 0 $number_of_tests
  start_time=`date +%s`
  end_time=$`date +%s`

  exit=1
  while [ ${exit} -gt 0 ];do
    counter=0
    number_of_devices_finish=0
    total_test_count=0
    for element in "${ports_array[@]}";do
      # On error detected
      device_fail=$(grep -of <(printf "%s\n" "${errors_tag_list[@]}") $log_folder/shard${counter}Instrumentation.log)
      if [ "${device_fail}" != "" ];then
        number_of_devices_finish=$((number_of_devices_finish+1))
      fi
      # On success detected
      device_success=$(grep -of <(printf "%s\n" "${success_tag_list[@]}") $log_folder/shard${counter}Instrumentation.log)
      if [ "${device_success}" != "" ];then
         number_of_devices_finish=$((number_of_devices_finish+1))
      fi

      ## PAINT PROGRESS BAR
      test_count=$(cat $log_folder/shard${counter}Instrumentation.log | grep "TestRunner: finished:" | wc -l)
      total_test_count=$(($total_test_count+$test_count))
      counter=$((counter+1))
    done

    ProgressBar "$barName" $total_test_count $number_of_tests
    end_time=$(date +%s)
    if [ "${number_of_devices_finish}" == "${number_of_devices}" ];then
      end_time=$(date +%s)
      ProgressBar "$barName" 1 1
      exit=0
    fi
    sleep 5
  done
  echo ""
}

function showShardTestResults {
  echo -e "   #############################################################"
  counter=0
  failed=false
  for port in "${ips_array[@]}";do

    shard_emoji=${emoji_list[RANDOM%${#emoji_list[@]} + 1]}
    result_base="   ## $shard_emoji Shard$counter                "
    result=$result_base

    # On error detected
    device_fail=$(grep -of <(printf "%s\n" "${errors_tag_list[@]}") $log_folder/shard${counter}Instrumentation.log)
    if [ "${device_fail}" != "" ];then
        device_status=$(echo $device_fail | xargs)
        result+="$RED $device_status $ENDCOLOR"
        failed=true

        ## COPY ERROR LOGS
        line_num=$(grep -n "Time: " $log_folder/shard${counter}Instrumentation.log | head -n 1 | cut -d: -f1)
        total_lines=$(cat $log_folder/shard${counter}Instrumentation.log | wc -l)
        tail -n $(($total_lines-$line_num)) $log_folder/shard${counter}Instrumentation.log > $log_folder/shard${counter}ErrorsInstrumentation.log
    fi
    # On success detected
    device_success=$(grep -of <(printf "%s\n" "${success_tag_list[@]}") $log_folder/shard${counter}Instrumentation.log)
    if [ "${device_success}" != "" ];then
       success_text=$(echo $device_success | sed -e "s/(//")
       result+="$GREEN $success_text $ENDCOLOR"
    fi

    ## REMOVE ?
    cresult=""
    IFS=' '
    for i in "$result";do
      cresult+="$i "
    done
    ## REMOVE ?

    lresult=$(complete_banner "$cresult" 78)
    echo -e "$lresult"
    counter=$((counter+1))
  done

  if [ "$failed" == "true" ];then
    printExecutionTime $RED
  else
    printExecutionTime $GREEN
  fi
}

function disconnectDevices() {
  #barName="   ## 📡$BOLD Disconnect devices  $NORMAL  "
  #ProgressBar "$barName" 0 1
  devices_json=$(curl -X GET "$STF_HOST/api/v1/devices" -H "Authorization: Bearer $TOKEN_STF" 2>&1)

  devices_serials_raw=$(echo $devices_json | grep -o '"serial":"[^"]*' | grep -o '[^"]*$')
  devices_serials=$(echo $devices_serials_raw | tr ' ' ',')
  IFS=', ' read -r -a device_serials_array <<< "$devices_serials"

  devices_urls_raw=$(echo $devices_json | grep -o '"remoteConnectUrl":"[^"]*' | grep -o '[^"]*$')
  devices_urls=$(echo $devices_urls_raw | tr ' ' ',')
  IFS=', ' read -r -a device_url_array <<< "$devices_urls"
  ndevices=$(echo "${#device_url_array[@]}")
  counter=0
  for device in "${device_url_array[@]}";do
      adb disconnect $device > /dev/null 2>&1
      counter=$((counter+1))
      #ProgressBar "$barName" $counter $ndevices
  done

  counter=0
  for serial in "${device_serials_array[@]}";do
    response=$(curl -X DELETE \
                     -H "Authorization: Bearer $TOKEN_STF" "$STF_HOST/api/v1/user/devices/$serial" 2>&1)
    counter=$((counter+1))
  done
}

function connectDevices() {
  #barName="   ## 📡$BOLD Connect devices     $NORMAL  "
  #ProgressBar "$barName" 0 1
  devices_json=$(curl -X GET "$STF_HOST/api/v1/devices" -H "Authorization: Bearer $TOKEN_STF" 2>&1)
  #devices_serials_raw=$(echo $devices_json | grep -o '"serial":"[^"]*' | grep -o '[^"]*$' | grep "192.*")
    devices_serials_raw=$(echo $devices_json | grep -o '"serial":"[^"]*' | grep -o '[^"]*$')
  devices_serials=$(echo $devices_serials_raw | tr ' ' ',')
  IFS=', ' read -r -a device_serials_array <<< "$devices_serials"
  ndevices=$(echo "${#device_serials_array[@]}")
  counter=0
  for serial in "${device_serials_array[@]}";do

      response=$(curl -X POST -H "Content-Type: application/json" \
                   -H "Authorization: Bearer $TOKEN_STF" \
                   --data "{\"serial\": \"$serial\"}" $STF_HOST/api/v1/user/devices 2>&1)

      response=$(curl -X POST "$STF_HOST/api/v1/user/devices/$serial/remoteConnect" \
                       --header "Authorization: Bearer $TOKEN_STF" 2>&1)

      response=$(echo $response | sed -e "s/[^{]*//")
      is_there_remote_connect_url=$(echo $response | jq .remoteConnectUrl)

      if [ "$is_there_remote_connect_url" != "null" ];then
         remote_connect_url=$(echo "$response" | grep -o '"remoteConnectUrl":"[^"]*' | sed -e 's/remoteConnectUrl":/ /' | tr -d '"' | tr -d ' ')
        adb connect $remote_connect_url 2>&1 > /dev/null
      fi

      counter=$((counter+1))
      #ProgressBar "$barName" $counter $ndevices
  done
  #echo ""
}

connectDevices

getDeviceArray
printBanner

buildApk
buildInstrumentationTest
installApp

# FAST! this is for the case of using adb to launch the tests
installInstrumentationTest
launchInstrumentationTestADB

monitoringInstrumentationTest
showShardTestResults

disconnectDevices
