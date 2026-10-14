@echo off
chcp 65001 >nul
cd /d "%~dp0"
start "" "D:\软件安装程序\Godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0."
