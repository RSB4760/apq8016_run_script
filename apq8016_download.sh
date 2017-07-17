#!/bin/bash

repo init -u https://github.com/RSB4760/apq8016_manifest_android -b advan_20170714_001 -m advan/LA.BR.1.2.7-01010-8x16.0_advan.xml
repo sync -j20
repo forall -c git checkout -b advan_20170714_001 tags/advan_20170714_001

