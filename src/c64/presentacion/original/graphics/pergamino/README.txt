MAPA
----

pergascr contiene la posición donde pintar cada cuadro.
pergagraf contiene el índice relativo del gráfico 
          a pintar y determina el final con 255
perga contiene los gráficos.

text1 contiene el texto inicial del pergamino. termina con 0x1a
letters contiene la definición de las letras (0x68ad - 0x727d)
pletters contiene el índice absoluto a las letras (0x678a - 0x6827)

pp.bin contiene todos los datos, menos textos:
0x0000/0x00b9 pergascr
0x00ba/0x0117 pergagraf
0x0118/0x02b5 perga
0x02b6/0x0355 pletters (absoluto, pasar a relativo)
0x0356/0x0d26 letters