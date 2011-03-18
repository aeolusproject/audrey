#!/bin/bash

cd src
thin -R config.ru -p 4567 start
