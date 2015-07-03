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

# Shortcut for grepping c code
gshort='alias grepc="grep -lr --include=\"*.[ch]\" --include=\"*.cpp\""'
if ! grep -Fxq "$gshort" ~/.bash_profile; then
    log_status "Adding grepc shortcut to ~/.bash_profile..."
    printf "\n%s\n" "$gshort" >> ~/.bash_profile
fi

gnshort='alias grepnc="grep -nr --include=\"*.[ch]\" --include=\"*.cpp\""'
if ! grep -Fxq "$gnshort" ~/.bash_profile; then
    log_status "Adding grepnc shortcut to ~/.bash_profile..."
    printf "\n%s\n" "$gnshort" >> ~/.bash_profile
fi

#Doing a system update
pup="alias pacman-system-update=\"pacman -S --needed bash pacman pacman-mirrors msys2-runtime\""
if ! grep -Fxq "$pup" ~/.bash_profile; then
    log_status "Adding pacman-system-update to ~/.bash_profile..."
    printf "\n%s\n" "$pup" >> ~/.bash_profile
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
    nppex='alias npp="\"$NPP\""'
	if ! grep -Fxq "$nppex" ~/.bash_profile; then
		log_status "Adding npp shortcut to ~/.bash_profile..."
        printf "\nNPP=\"%s\"\n" "$npp" >> ~/.bash_profile
		printf "%s\n" "$nppex" >> ~/.bash_profile
	fi;
	
	log_status "Using notepad++ as git editor..."
	git config --global core.editor "'$npp' -multiInst -notabbar -nosession -noPlugin"
fi

source ~/.bash_profile
log_status "Done. You may have to restart the terminal for the changes to work."