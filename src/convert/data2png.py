from PIL import Image
import struct
import ctypes
import sys

if len(sys.argv) == 3:
	data_path = sys.argv[1]
	img_path = sys.argv[2]
else:
	data_path = input("Введите путь к файлу .data: ")
	img_path = input("Введите, куда сохранить .png: ")

fin = open(data_path, 'rb')
(w, h) = struct.unpack('ii', fin.read(8))
buff = ctypes.create_string_buffer(4 * w * h)
fin.readinto(buff)
fin.close()
img = Image.new('RGBA', (w, h))
pix = img.load()
offset = 0
for j in range(h):
	for i in range(w):
		(r, g, b, a) = struct.unpack_from('cccc', buff, offset)
		pix[i, j] = (ord(r), ord(g), ord(b), 255)
		offset += 4
img.save(img_path)
