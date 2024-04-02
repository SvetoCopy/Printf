gcc -c main.cpp -o main.o
nasm -f win64 printf.asm -o printf.o
gcc -o main.exe main.o printf.o -lgcc -l kernel32