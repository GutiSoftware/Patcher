# Patcher
This application compares two files of equal length and creates a text file with the differences. These differences are displayed with their Offset, and also specify their VA (Virtual Address) and RVA (Relative Virtual Address), and if they are bytes of DLL Characteristics, this is also specified.
As additional information, it is indicated whether it is a PE Windows 32/64 bit file or not.
The reverse operation can also be performed, creating the Original or Modified file with the differences file. To ensure that the files are those that were used to create the differences file, the CRC32 of these is calculated and included.
