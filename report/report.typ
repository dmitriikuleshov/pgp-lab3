// Лабораторная работа № 3
// Титульный лист отделён от шаблона modern-g7-32,
// чтобы номер страницы 1 не отображался.

#import "@preview/modern-g7-32:0.2.0": gost

// -----------------------------------------------------------------------------
// ТИТУЛЬНЫЙ ЛИСТ
// -----------------------------------------------------------------------------

// Титульный лист создаётся ДО подключения шаблона modern-g7-32.
// Поэтому пакет не может вывести на нём номер страницы.
#set page(
  paper: "a4",
  margin: (left: 30mm, right: 15mm, top: 20mm, bottom: 20mm),
  numbering: none,
  footer: none,
)

#set text(font: "Times New Roman", size: 14pt, lang: "ru")

#block[
#set par(first-line-indent: 0pt, justify: false)

#grid(
  columns: (1fr,),
  rows: (auto, 1fr, auto, 1fr, auto, 1fr, auto),
  row-gutter: 0pt,

  align(center)[
    #text(weight: "bold")[МОСКОВСКИЙ АВИАЦИОННЫЙ ИНСТИТУТ] \
    #text(weight: "bold")[(НАЦИОНАЛЬНЫЙ ИССЛЕДОВАТЕЛЬСКИЙ УНИВЕРСИТЕТ)]
    #v(6mm)
    Институт № 8 «Компьютерные науки»
  ],

  [],

  align(center)[
    #text(weight: "bold")[ЛАБОРАТОРНАЯ РАБОТА № 3] \
    по курсу «Программирование графических процессоров»
    #v(7mm)
    #text(weight: "bold")[
      «Классификация и кластеризация изображений на GPU»
    ]
  ],

  [],

  align(right)[
    #block(width: 92mm)[
      #table(
        columns: (40mm, 1fr),
        stroke: none,
        inset: (x: 0pt, y: 3pt),
        align: (left, left),
        [Выполнил:], [Д. А. Кулешов],
        [Группа:], [М8О-408Б-23],
        [Преподаватель:], [А. Ю. Морозов],
      )
    ]
  ],

  [],

  align(center)[Москва 2026],
)
]

#pagebreak()


// -----------------------------------------------------------------------------
// С ЭТОГО МЕСТА РАБОТАЕТ modern-g7-32
// -----------------------------------------------------------------------------

#show: gost.with(
  hide-title: true,
  text-size: (default: 14pt, small: 12pt),
  indent: 1.25cm,
  margin: (
    left: 30mm,
    right: 15mm,
    top: 20mm,
    bottom: 20mm,
  ),
  pagination-align: center,
  add-pagebreaks: false,
)

#set text(font: "Times New Roman", lang: "ru")
#show raw: set text(font: "Courier New", size: 12pt)

#let cuda-config(blocks, threads) = raw(
  "<<<" + str(blocks) + ", " + str(threads) + ">>>"
)

#let mono(body) = text(font: "Courier New", size: 12pt, body)

#let parse-benchmark(path) = {
  let results = ()

  for line in read(path).split("\n") {
    let measurement = line.match(regex(
      "w=(\\d+) h=(\\d+) classes=(\\d+) blocks=(\\d+) threads=(\\d+) GPU=([0-9.]+) ms CPU=([0-9.]+) ms"
    ))

    if measurement != none {
      let values = measurement.captures
      let gpu = float(values.at(5))
      let cpu = float(values.at(6))

      results.push((
        input: values.at(0) + "×" + values.at(1),
        classes: int(values.at(2)),
        blocks: int(values.at(3)),
        threads: int(values.at(4)),
        gpu: gpu,
        cpu: cpu,
        speedup: cpu / gpu,
      ))
    }
  }

  results
}

#let decimal(value, digits: 6) = {
  str(calc.round(value, digits: digits)).replace(".", ",")
}

#let benchmark-results = parse-benchmark("benchmark_results.txt")
#let small-results = benchmark-results.slice(0, 6)
#let medium-results = benchmark-results.slice(6, 12)
#let large-results = benchmark-results.slice(12, 18)
#let best(rows) = rows.sorted(key: row => row.gpu).first()

// -----------------------------------------------------------------------------
// ОСНОВНАЯ ЧАСТЬ
// -----------------------------------------------------------------------------

= Условие

#figure(
  image("task/task_part1.png", width: 100%),
  caption: [Общая постановка задачи и формат входных данных],
) <task-general>

#figure(
  image("task/task_part2.png", width: 100%),
  caption: [Условие варианта 3 — метод минимального расстояния],
) <task-variant>

= Программное и аппаратное обеспечение

== Аппаратное обеспечение

Характеристики использованного аппаратного обеспечения приведены в таблице 1.

// Таблицы оставлены разбиваемыми штатными средствами modern-g7-32.
// table.header(...) повторяет шапку при переносе на следующую страницу.
// Для очень длинной таблицы над продолжением по ГОСТ требуется надпись
// «Продолжение таблицы X»; modern-g7-32 не добавляет её автоматически,
// поэтому при реальном многостраничном переносе такую таблицу нужно
// редакторски разделить на части и подписать продолжение вручную.
#figure(
  table(
    columns: (42%, 58%),
    stroke: 0.5pt,
    inset: (x: 4pt, y: 4pt),
    align: (left, left),
    table.header(
      [#align(center)[Характеристика]],
      [#align(center)[Значение]],
    ),
    [Процессор], [AMD Ryzen 5 5600, 6 ядер, 12 потоков],
    [Кэш процессора], [L1d — 192 KiB; L1i — 192 KiB; L2 — 3 MiB; L3 — 32 MiB],
    [Оперативная память], [32 GiB; в WSL доступно 15 GiB; swap 4 GiB],
    [Накопитель], [INTEL SSDPEKNU512GZ, 512 GB],
    [Графический процессор], [NVIDIA GeForce RTX 5070],
    [Compute capability], [12.0],
    [Графическая память], [12 227 MiB],
    [Разделяемая память на блок], [49 152 байт (48 KiB)],
    [Константная память], [65 536 байт (64 KiB)],
    [Регистров на блок], [65 536],
    [Максимальное число нитей в блоке], [1024],
    [Максимальный размер сетки], [2 147 483 647 × 65 535 × 65 535 блоков],
    [Число мультипроцессоров], [48],
  ),
  caption: [Характеристики аппаратного обеспечения],
) <hardware-table>

Характеристики GPU были получены с помощью `nvidia-smi` и функции
`cudaGetDeviceProperties`.

== Программное обеспечение

Использованное программное обеспечение приведено в таблице 2.

#figure(
  table(
    columns: (42%, 58%),
    stroke: 0.5pt,
    inset: (x: 4pt, y: 4pt),
    align: (left, left),
    table.header(
      [#align(center)[Компонент]],
      [#align(center)[Значение]],
    ),
    [Операционная система], [Ubuntu 26.04.1 LTS в WSL],
    [Архитектура], [x86-64],
    [CUDA Toolkit], [13.4],
    [Компилятор CUDA], [nvcc 13.4.92],
    [Драйвер NVIDIA], [617.14],
    [Среда разработки], [Visual Studio Code],
  ),
  caption: [Использованное программное обеспечение],
) <software-table>

= Метод решения

Для каждого класса $j$ по заданной выборке пикселей вычисляется средний вектор
цвета

$ "avg"_j = 1 / n_(p_j) sum_(i=1)^(n_(p_j)) p_i^j, $

где $p_i^j = (r_i^j, g_i^j, b_i^j)^T$ — пиксель из выборки класса $j$,
$n_(p_j)$ — размер этой выборки.

Для произвольного пикселя $p$ вычисляется квадрат евклидова расстояния до
среднего вектора каждого класса:

$ d_j(p) = (p - "avg"_j)^T (p - "avg"_j). $

Пиксель относится к классу с минимальным расстоянием:

$ j_c = "arg min"_j d_j(p). $

Это равносильно максимизации отрицательного расстояния, указанной в условии.
Если минимальное расстояние одинаково для нескольких классов, сохраняется класс
с меньшим номером.

Средние векторы вычисляются на CPU и копируются в константную память GPU. Все
пиксели хранятся в линейном массиве. Нити одномерной CUDA-сетки обрабатывают их
независимо и после каждого пикселя смещаются на полный размер сетки. Номер класса
записывается в альфа-канал, компоненты RGB не изменяются. Вычислительная
сложность алгоритма составляет $O(w h n_c)$.

= Описание программы

Работа состоит из следующих файлов:

- #mono[src/cuda/lab3.cu] — основная CUDA-программа;
- #mono[src/cuda/benchmark.cu] — CPU-реализация, проверка корректности и
  измерение производительности разных конфигураций CUDA;
- #mono[src/convert/png2data.py], #mono[src/convert/data2png.py] и
  #mono[src/convert/data2classes.py] — преобразование изображений и
  визуализация номеров классов;
- #mono[Makefile] — сборка программ и отчёта.

Пиксели представлены типом #mono[uchar4]. Средние векторы цветов представлены
типом #mono[double3] и хранятся в массиве #mono[class_averages] в константной
памяти. Исходное изображение копируется в линейную память GPU и классифицируется
на месте.

== CUDA-ядро

Ядро #mono[kernel] вычисляет линейный индекс пикселя по индексам блока и нити.
Для пикселя последовательно вычисляются расстояния до средних цветов классов.
Используется строгое сравнение #mono[distance < min_distance], поэтому при
равных расстояниях выбирается класс с меньшим номером. Цикл с шагом, равным
общему числу нитей, позволяет обрабатывать изображения любого допустимого
размера одной конфигурацией запуска.

== CPU-версия

Функция #mono[cpu_classify] из файла #mono[benchmark.cu] реализует тот же
алгоритм последовательным циклом. После каждого измерения результаты CPU и GPU
сравниваются попиксельно, включая номер класса в альфа-канале.

= Результаты

== Проведение замеров

Время CUDA-ядра измерялось с помощью CUDA Events, время CPU-версии — с помощью
#mono[chrono]. Перед замерами выполнялся прогрев. Копирование данных между CPU и
GPU не учитывалось. Для изображений 1024 × 1024, 4096 × 4096 и 8192 × 8192
выполнялось соответственно 50, 10 и 3 повтора. В каждом тесте использовалось
пять классов. В таблицах указано среднее время одного запуска. Программы собраны
с оптимизацией #mono[-O2].

== Время работы CUDA-ядра

Результаты измерения времени CUDA-ядра приведены в таблице @cuda-time-table.
Единица измерения — миллисекунда.

#figure(
  table(
    columns: (25%, 25%, 25%, 25%),
    stroke: 0.5pt,
    inset: (x: 3pt, y: 4pt),
    align: (center, right, right, right),
    table.header(
      [#align(center)[Конфигурация]],
      [#align(center)[1024 × 1024, мс]],
      [#align(center)[4096 × 4096, мс]],
      [#align(center)[8192 × 8192, мс]],
    ),
    ..range(6).map(i => (
      [#cuda-config(small-results.at(i).blocks, small-results.at(i).threads)],
      [#decimal(small-results.at(i).gpu)],
      [#decimal(medium-results.at(i).gpu)],
      [#decimal(large-results.at(i).gpu)],
    )).flatten(),
  ),
  caption: [Среднее время работы CUDA-ядра],
) <cuda-time-table>

Конфигурация #cuda-config(1, 32) использует только один warp и поэтому плохо
подходит для больших изображений. После насыщения GPU дальнейшее увеличение
числа нитей почти не сокращает время работы.

== Сравнение с CPU

Ускорение вычисляется по формуле

$ S = T_"CPU" / T_"GPU", $

где $T_"CPU"$ — среднее время последовательной версии, а $T_"GPU"$ — среднее
время CUDA-ядра. Для каждого размера в таблице @cpu-gpu-table выбрана самая
быстрая из измеренных конфигураций.

#let best-small = best(small-results)
#let best-medium = best(medium-results)
#let best-large = best(large-results)

#figure(
  table(
    columns: (20%, 18%, 18%, 26%, 18%),
    stroke: 0.5pt,
    inset: (x: 3pt, y: 4pt),
    align: (center, right, right, center, right),
    table.header(
      [#align(center)[Вход]],
      [#align(center)[CPU, мс]],
      [#align(center)[GPU, мс]],
      [#align(center)[Конфигурация]],
      [#align(center)[Ускорение]],
    ),
    [#best-small.input],
    [#decimal(best-small.cpu)],
    [#decimal(best-small.gpu)],
    [#cuda-config(best-small.blocks, best-small.threads)],
    [#decimal(best-small.speedup, digits: 2)],
    [#best-medium.input],
    [#decimal(best-medium.cpu)],
    [#decimal(best-medium.gpu)],
    [#cuda-config(best-medium.blocks, best-medium.threads)],
    [#decimal(best-medium.speedup, digits: 2)],
    [#best-large.input],
    [#decimal(best-large.cpu)],
    [#decimal(best-large.gpu)],
    [#cuda-config(best-large.blocks, best-large.threads)],
    [#decimal(best-large.speedup, digits: 2)],
  ),
  caption: [Сравнение времени CPU и лучшей конфигурации GPU],
) <cpu-gpu-table>

Результаты CPU и GPU совпали попиксельно. Конфигурация #cuda-config(1, 32)
медленнее CPU, но при достаточном числе блоков GPU показывает значительное
ускорение. Время копирования памяти в это сравнение не входит.

== Результат обработки изображения

Для проверки использовано изображение размером 800 × 800 пикселей и пять
выборок характерных цветов. В выходном файле исходные компоненты RGB сохранены,
а номер класса записан в альфа-канал. Поэтому справа на рисунке
@image-result приведена цветовая визуализация значений альфа-канала: каждому
классу соответствует отдельный цвет.

#figure(
  grid(
    columns: (1fr, 1fr),
    gutter: 8mm,
    [
      #image("shrek/shrek.png", width: 100%)
      #align(center)[#par(justify: false)[а) исходное изображение, 800 × 800]]
    ],
    [
      #image("shrek/shrek_classes.png", width: 100%)
      #align(center)[#par(justify: false)[б) визуализация результата классификации]]
    ],
  ),
  caption: [Результат классификации изображения методом минимального расстояния],
) <image-result>

= Выводы

В работе реализована классификация пикселей методом минимального расстояния на
GPU. Средние векторы классов размещены в константной памяти, а обработка
пикселей распределена между нитями одномерной CUDA-сетки.

Для изображений размером 1024 × 1024, 4096 × 4096 и 8192 × 8192 получено
ускорение соответственно в #decimal(best-small.speedup, digits: 2),
#decimal(best-medium.speedup, digits: 2) и
#decimal(best-large.speedup, digits: 2) раза относительно последовательной
CPU-версии. Конфигурация с одним блоком не обеспечивает достаточного параллелизма
и уступает CPU. Попиксельное совпадение результатов подтвердило корректность
CUDA-реализации.

Исходный код работы: #underline[
  #link("https://github.com/dmitriikuleshov/pgp-lab3")[https://github.com/dmitriikuleshov/pgp-lab3]
]
