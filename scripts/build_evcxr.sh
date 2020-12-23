#!/bin/bash
v=`rustc --version | awk '{ print $2 }' | cut -d. -f2`
if [ _"$v"  = _"" ] || [ $v -le 43 ]; then
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > /tmp/rust-init-$$.sh
	chmod 755 /tmp/rust-init-$$.sh
	/tmp/rust-init-$$.sh -y
fi
	. $HOME/.profile && cargo install cargo-script && cargo install evcxr_jupyter --no-default-features
	cp ~/.cargo/bin/evcxr_jupyter $HOME/jupyter-procmail/
if [ _"$v"  = _"" ] || [ $v -le 43 ]; then
	/tmp/rust-init-$$.sh self uninstall
	rm -f /tmp/rust-init-$$.sh
fi
