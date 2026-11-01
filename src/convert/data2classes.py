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

colors = [
	(253, 231, 37),
	(94, 201, 98),
	(33, 145, 140),
	(59, 82, 139),
	(68, 1, 84),
]

fin = open(data_path, 'rb')
(w, h) = struct.unpack('ii', fin.read(8))
buff = ctypes.create_string_buffer(4 * w * h)
fin.readinto(buff)
fin.close()
img = Image.new('RGB', (w, h))
pix = img.load()
offset = 0
for j in range(h):
	for i in range(w):
		(r, g, b, a) = struct.unpack_from('BBBB', buff, offset)
		pix[i, j] = colors[a]
		offset += 4
img.save(img_path)
