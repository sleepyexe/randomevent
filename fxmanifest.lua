fx_version 'cerulean'
game 'gta5'

name "secure"
description "sercure"
author "secure"
version "1.0.0"
lua54 'yes'

amankan {
	'secure',
	'sr_scripts',
	'test'
}

shared_scripts {
	'shared/*.lua'
}

client_scripts {
	'client/*.lua'
}

server_scripts {
	'server/*.lua'
}
