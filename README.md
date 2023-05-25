# Patcher
This application compares two files of equal length and creates a text file with the differences. These differences are displayed with their Offset, and also specify their VA (Virtual Address) and RVA (Relative Virtual Address), and if they are bytes of DLL Characteristics, this is also specified.
As additional information, it is indicated whether it is a PE Windows 32/64 bit file or not.
The reverse operation can also be performed, creating the Original or Modified file with the differences file. To ensure that the files are those that were used to create the differences file, the CRC32 of these is calculated and included.


Parcheador
Esta aplicación compara dos archivos de igual longitud y crea un fichero de texto con las diferencias. Estas diferencias además de mostrarse con su Ofsset, se especifica tambien su VA (Driección virtual) y su RVA (dirección virtual relativa) y si se trata de los bytes de las DLL Characteristics se especifica tambien.
Como información adicinal se indica si es un fichero PE windows 32/64 bits o no.
tambien se puede realizar la operación inversa, crear el archivo Original o el Modificado con el fichero de diferencias. Para garantizar que los archivos son los que se utilizaron para crear el fichero de diferencias, se calcula y se incluye el CRC32 de estos
