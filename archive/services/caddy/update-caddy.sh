#!/bin/bash
docker pull caddy:2-builder
docker pull caddy:2
docker build -t custom-caddy:latest .
