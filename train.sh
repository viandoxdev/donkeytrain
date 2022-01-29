#!/bin/bash

# TODO: maybe check if pass is empty in config_check when sshpass is installed.

# to make things look nicer
echo

# check if command exists
check_command() {
	command -v "$1" &>/dev/null || \
		{ echo "$1 is required for this script to run"; exit 127; }
}

check_command "printf"
bold=$(printf '\033[1m')
reset=$(printf '\033[0m')
yellow=$(printf '\033[33m')
bright_green=$(printf '\033[92m')
bright_red=$(printf '\033[91m')

mkdir -p data
mkdir -p models
if ! [ -f "config" ]; then
	{
		echo "# This is the config file for remote access"
		echo "# please fill in the correct values for the"
		echo "# upload and download commands."
		echo "ip	0.0.0.0"
		echo "user	pi"
		echo "pass	123456"
		echo "data	/home/pi/mycar/data"
		echo "models	/home/pi/mycar/models"
	} > config
	echo "${bright_red}${bold}created config file, please review before continuing.${reset}"
	echo
fi

# finds the length of the longest element of an array
max_length() {
	array=("$@")
	((l))
	typeset -i l
	for i in "${array[@]}"; do
		a=${#i}
		l=$((l > a ? l : a))
	done
	echo "$l"
}

# padds str (1) to length (2)
rspad() {
	str_len=${#1}
	padded_len=$2
	pad=$((padded_len - str_len))
	printf "$1%${pad}s\n"
}

config_get() {
	check_command "awk"
	awk '$1=="'"$1"'" {print $2}' < config
}

config_check() {
	ip=$(config_get "ip")
	user=$(config_get "user")
	pass=$(config_get "pass")
	data=$(config_get "data")
	models=$(config_get "models")

	# thanks stackoverflow! (https://stackoverflow.com/a/35701965)
	[[ "$ip" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]] || \
		{ echo "${bright_red}invalid ip field in config${reset}"; exit 1; }
	[ -z "$user" ] && \
		{ echo "${bright_red}invalid user field in config${reset}"; exit 1; }
	# pass is optional
	[ -z "$data" ] && \
		{ echo "${bright_red}invalid data field in config${reset}"; exit 1; }
	[ -z "$models" ] && \
		{ echo "${bright_red}invalid models field in config${reset}"; exit 1; }
}

help() {
	commands=(
		"setup"
		"run"
		"download"
		"upload"
		"help"
	)
	arguments=(
		""
		"data model-name "
		"data-name"
		"model-name"
		"[about]"
	)
	descriptions=(
		"run setup"
		"train model on [data], will write to models/[model-name]"
		"download training data from pi to data/[data-name] (see help config)"
		"upload model [model-name] to pi (see help config)"
		"shows this page"
	)
	
	cml=$(max_length "${commands[@]}")
	aml=$(max_length "${arguments[@]}")

	typeset -i i len
	len=${#commands[@]}
	echo "availibles commands:"
	for ((i=0;i<len;i++)); do
		c=$(rspad "${commands[i]}" "$cml")
		a=$(rspad "${arguments[i]}" "$aml")
		echo "    ${bold}${c} ${reset}${bright_green}${a}${reset}${descriptions[i]}"
	done
}

help_config() {
	echo "The config is used by the upload and download commands to know where to read/write."
	echo "It is made of fields, one per line in tab separated key/value pairs"
	echo "The convention for comments is #, but any line that doesn't start with a known field will be ignored."
	echo
	echo "fields: (? means optional)"
	fields=(
		"ip"
		"user"
		"pass?"
		"data"
		"models"
	)
	descriptions=(
		"the ip address of the pi"
		"the user to connect with"
		"if sshpass is installed, will use this field as the password."
		"where the training data are stored on the pi"
		"where to write the models"
	)
	
	fml=$(max_length "${fields[@]}")

	typeset -i i len
	len=${#fields[@]}
	for ((i=0;i<len;i++)); do
		f=$(rspad "${fields[i]}" "$fml")
		echo "    ${bold}$f ${reset}${bright_green}${descriptions[i]}${reset}"
	done
}

setup() {
	check_command "docker"
	docker build . -t donkey
}

run() {
	# we know $1 is a directory
	abs=$(cd "$1" && pwd -P || exit)
	mkdir -p "models/${2}"
	# train
	check_command "docker"
	docker run -v "${abs}:/home/mambauser/data" -v "$(pwd -P)/models/${2}:/home/mambauser/car/models" donkey
}

download() {
	data_path=$(config_get "data")
	ip=$(config_get "ip")
	user=$(config_get "user")
	pass=$(config_get "pass")

	check_command "scp"
	check_command "ssh"
	check_command "tar"

	if command -v sshpass &>/dev/null; then
		echo "${bright_green}compressing data"
		sshpass -p "$pass" ssh "${user}@${ip}" -f "cd ~/mycar && tar cvzf ${data_path}.tar.gz $data_path"

		echo "${bright_green}copying archive"
		sshpass -p "$pass" scp -r "${user}@${ip}:${data_path}.tar.gz" "data/data.tar.gz"

		echo "${bright_green}extracting archive"
		tar xvf data/data.tar.gz -C data/
		mv data/data "data/$1"
	else
		echo "${yellow}consider installing sshpass for automatic password entry (with config)"

		echo "${bright_green}compressing data"
		ssh "${user}@${ip}" -f "cd ~/mycar && tar cvzf ${data_path}.tar.gz $data_path"

		echo "${bright_green}copying archive"
		scp -r "${user}@${ip}:${data_path}.tar.gz" "data/data.tar.gz"

		echo "${bright_green}extracting archive"
		tar xvf data/data.tar.gz -C data/
		mv data/data "data/$1"
	fi
}

upload() {
	models_path=$(config_get "models")
	ip=$(config_get "ip")
	user=$(config_get "user")
	pass=$(config_get "pass")

	check_command "scp"
	if command -v sshpass &>/dev/null; then
		sshpass -p "$pass" scp -r -v "models/$1" "${user}@${ip}:${models_path}"
	else
		echo "${yellow}consider installing sshpass for automatic password entry (with config)"
		scp -r "models/$1" "${user}@${ip}:${models_path}"
	fi
}

arg_error() {
	echo "invalid argument '$1': $2"
	exit 1
}

case "$1" in
	"setup")
		setup
		;;
	"run")
		[ -d "$2" ] || arg_error "$2" "no such directory"
		[[ "$3" =~ ^[A-Za-z_0-9-]+$ ]] || arg_error "$3" "must match against /^[A-Za-z_0-9-]+$/"
		run "$2" "$3"
		;;
	"download")
		[[ "$2" =~ ^[A-Za-z_0-9-]+$ ]] || arg_error "$2" "must match against /^[A-Za-z_0-9-]+$/"
		config_check
		download "$2"
		;;
	"upload")
		[[ "$2" =~ ^[A-Za-z_0-9-]+$ ]] || arg_error "$2" "must match against /^[A-Za-z_0-9-]+$/"
		[ -d "models/$2" ] || arg_error "$2" "model doesn't exist"
		config_check
		upload "$2"
		;;
	"help")
		case "$2" in
			"config")
				help_config
				;;
			"")
				help
				;;
			*)
				echo "unknown topic"
				help
				;;
		esac
		;;
	*)
		echo "unknown command $1"
		help
		exit 127
		;;
esac
