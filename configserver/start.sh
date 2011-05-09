#!/bin/bash

cd src
thin -V -R config.ru -p 4567 start
