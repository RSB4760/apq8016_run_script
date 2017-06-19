#!/bin/bash

repo init -u https://github.com/RSB4760/apq8016_manifest_android -b LA.BR.1.2.7-01010-8x16_advan -m advan/LA.BR.1.2.7-01010-8x16.0_advan.xml
repo sync -j20
repo forall -c git checkout -b LA.BR.1.2.7-01010-8x16_advan advantech-github/LA.BR.1.2.7-01010-8x16_advan

