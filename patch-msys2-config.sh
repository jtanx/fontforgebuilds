#!/usr/bin/sh

# Yellow text
function log_status() {
    echo -e "\e[33m$@\e[0m"
}

irc=$(cat inputrc-config.txt)
if ! grep -Fxq "$irc" ~/.inputrc; then
	log_status "Patching .inputrc..."
	cat inputrc-config.txt >> ~/.inputrc
	bind -f ~/.inputrc
fi

npp="C:/Program Files/Notepad++/notepad++.exe"
if [ ! -f "$npp" ]; then
	npp="C:/Program Files (x86)/Notepad++/notepad++.exe"
	if [ ! -f "$npp" ]; then
		npp=""
	fi;
fi

# We have Notepad++
if [ ! -z "$npp" ]; then
	nppex="alias npp=\"\\\"$npp\\\"\""
	if ! grep -Fxq "$nppex" ~/.bash_profile; then
		log_status "Adding npp shortcut to ~/.bash_profile..."
		printf "\n%s\n" "$nppex" >> ~/.bash_profile
	fi;
	
	log_status "Using notepad++ as git editor..."
	git config --global core.editor "'$npp' -multiInst -notabbar -nosession -noPlugin"
fi

log_status "Done. You may have to restart the terminal for the changes to work."