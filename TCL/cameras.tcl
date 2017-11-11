# cameras.tcl

array unset g_camPresets
set g_camPresets(Sunny)        [list 2740.000000 1024.000000 1640.000000]
set g_camPresets(Shady)        [list 3228.000000 1024.000000 1356.000000]
set g_camPresets(Cloudy)       [list 2948.000000 1024.000000 1508.000000]
set g_camPresets(Tungsten)     [list 1668.000000 1024.000000 2888.000000]
set g_camPresets(Fluorescent)  [list 2404.000000 1024.000000 2280.000000]

set RAW_EXTENSION ""
set KNOWN_RAW_EXTENSIONS_DICT [dict create \
  "iiq"   Phase-One   \
  "3fr"   Hasselblad  \
  "dcr"   Kodak       \
  "k25"   Kodak       \
  "kdc"   Kodak       \
  "cr2"   Canon       \
  "crw"   Canon       \
  "dng"   Adobe       \
  "erf"   Epson       \
  "mef"   Mamiya      \
  "mos"   Leaf        \
  "mrw"   Minolta     \
  "nef"   Nikon       \
  "orf"   Olympus     \
  "pef"   Pentax      \
  "rw2"   Panasonic   \
  "arw"   Sony        \
  "srf"   Sony        \
  "sr2"   Sony        \
                      ]
