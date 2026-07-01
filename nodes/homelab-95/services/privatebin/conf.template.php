; https://github.com/PrivateBin/PrivateBin/blob/master/cfg/conf.sample.php

[main]
basepath = "https://${PRIVATEBIN_DOMAIN}/"
; header = "X_FORWARDED_FOR"
fileupload = true
sizelimit = 20971520 ; 20 MB
default = "1day"
forcehttps = true

[model]
; where to store pastes
class = Filesystem

[model_options]
dir = PATH "data"

[traffic]
limit = 5
; IPs or subnets that are not subject to the rate limit
exempted = "192.168.50.0/24,192.168.88.0/24,10.0.0.0/8"

; IPs or subnets that are allowed to create
creators = "192.168.50.0/24,192.168.88.0/24,10.0.0.0/8"
