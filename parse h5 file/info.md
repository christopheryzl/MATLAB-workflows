# Structure of the `readFromList` output

`readFromList(fileName, groups, ...)` returns a single MATLAB `table` named
`Results`. The function itself does not write to disk — save it with e.g.

```matlab
Results = readFromList(fileName, groups);
save("cases.mat", "Results");
```

so the `.mat` file contains one variable, `Results`.

## Top level: `Results`

One **row per case group** passed in `groups` (in the order given).

| Column            | Type                | Contents                                             |
| ----------------- | ------------------- | ---------------------------------------------------- |
| *case attributes* | one column each     | read dynamically from the h5 group attributes         |
| `noise data`      | cell → table        | per-microphone noise table for that case              |
| `load data`       | cell → table        | per-case load table (**currently an empty stub**)     |
| `encoder data`    | cell → table        | per-case angular encoder table                        |

### Case attribute columns

Not hard-coded. Whatever attributes exist on the first group become columns,
with the attribute name used verbatim as the column name. For the current
dataset these are:

`boom`          : Width of boom, 
`hsep`          : Horiztonal separation,
`rpm`           : (Nominal) rotation speed,
`rpm_front`     : Actual rotation speed front,
`rpm_rear`      : Actual rotation speed rear,
`phase`         : Relative phase angle,
`file`          : Name of original tdms file,
`create_time`   : Time of creation,
`run`           : Run number,
`duration`      : Acquisition time,
`vsep`          : Vertical separation,
`inflow`        : Inflow velocity,
`tilt`          : Inflow angle,
`delta_rpm`     : Rotation speed difference between front and rear 

Access with dot syntax, or bracket syntax when the name is not a valid
identifier:

```matlab
Results.rpm(caseIdx)
Results.("hsep")(caseIdx)
```

## `Results.("noise data"){caseIdx}` — noise table

One **row per microphone**, ordered by mic index (`mic1`, `mic2`, ...). Which
mics appear depends on the `Mics` option; by default every `mic#`/`Mic#`
subgroup found in the file is read.

| Column               | Type          | Contents                                          |
| -------------------- | ------------- | ------------------------------------------------- |
| *mic attributes*     | one column each| read dynamically from the h5 microphone attributes |
| `<group>`            | cell → table  | spectrum table for that group (see below)          |
| `<group>_OASPL`      | double scalar | overall SPL for that group                         |

`<group>` is one of the spectrum subgroups requested via the `SpecGroups`
option, defaulting to `["df1","df4"]`. So by default the columns are:

`df1`, `df1_OASPL`, `df4`, `df4_OASPL`

Mic attribute columns for the current dataset:

`fs`        : Sampling frequency,
`channel`   : NI channel,
`serial`    : Microphone serial,
`theta`     : Polar angle,
`phi`       : Azimuth angle,
`r`         : Radial distance from datum


### `<group>` spectrum table

One **row per frequency bin**.

| Column | Type   | Contents               |
| ------ | ------ | ---------------------- |
| `f`    | double | frequency [Hz]         |
| `psd`  | double | power spectral density |
| `spl`  | double | sound pressure level   |

## `Results.("encoder data"){caseIdx}` — encoder table

One **row per encoder sample**.

| Column  | Type   | Contents                 |
| ------- | ------ | ------------------------ |
| `front` | double | front motor angle        |
| `rear`  | double | rear motor angle         |

## `Results.("load data"){caseIdx}` — load table

Currently an **empty table** (`table()`). `readLoadData` is a stub; the column
exists so the output shape stays stable once load reading is implemented.

## Reaching the raw data: the `file` attribute

The h5 dataset stores only *processed* results — spectra, OASPL, encoder
angles. The raw acoustic pressure time series is **not** in the h5; it lives in
the original TDMS acquisition files. The `file` case attribute is the link
between the two: for each case it holds the name of the TDMS file that case was
processed from.

Deliberately, `file` stores only the file *name*, not a full path. The folder
holding the raw TDMS files is supplied separately by the calling script. This
keeps the h5 portable — the raw data can be moved, or accessed from a different
machine or drive, without invalidating the dataset.

Reading a raw microphone trace is therefore a three-step lookup:

1. **Pick the case.** Filter or index `Results` on the case attributes
   (`rpm`, `hsep`, `phase`, ...) to get the row you want. Take `Results.file`
   from that row.
2. **Find the microphone channel.** Open that case's noise table and filter its
   microphone attribute columns — `theta`, `phi` and `r` — for the observer
   position of interest. The `channel` column of the matching row *is* the NI
   channel name to read from the TDMS file; no further lookup is needed.
3. **Read that channel only.** Join the script-supplied raw-data folder with
   the `file` name to form the TDMS path, then read *partially*: request just
   the channel(s) resolved in step 2 rather than loading the whole file. A
   single TDMS file holds every microphone for the run, so a full read is
   expensive and almost always unnecessary.

Sketch of the intended call pattern:

```matlab
rawFolder = "D:\raw tdms";                     % set in the calling script

caseIdx   = find(Results.rpm == 4000 & Results.phase == 0, 1);
tdmsPath  = fullfile(rawFolder, Results.file(caseIdx));

noiseTable = Results.("noise data"){caseIdx};
micMask    = noiseTable.theta == 90 & noiseTable.phi == 0;
channel    = noiseTable.channel(micMask);      % NI channel name(s)
fs         = noiseTable.fs(micMask);           % sampling frequency

% -> read only `channel` from tdmsPath
```

Filtering on `theta`/`phi`/`r` should isolate a single row for a well-posed
query; if it returns more than one, the position is ambiguous and the query
needs tightening. Because the mic attributes travel with the noise table, the
matching row also carries `fs` and `serial`, so the raw trace arrives with
everything needed to interpret it.

## Access examples

```matlab
% RPM of case 3
Results.rpm(3)

% noise table for case 3
noiseTable = Results.("noise data"){3};

% OASPL of mic 12, case 3, df1 group
noiseTable.df1_OASPL(12)

% df4 spectrum of mic 12, case 3
spec = noiseTable.df4{12};
loglog(spec.f, spec.psd)

% front motor angle trace for case 3
enc = Results.("encoder data"){3};
plot(enc.front)
```

## Nesting summary

```
Results                         (table, 1 row per case)
├── <case attributes>           (rpm, tilt, file, ...)
├── noise data      {case}      (table, 1 row per mic)
│   ├── <mic attributes>        (fs, channel, serial, theta, phi, r)
│   ├── df1         {mic}       (table, 1 row per frequency bin: f, psd, spl)
│   ├── df1_OASPL               (scalar)
│   ├── df4         {mic}       (table, 1 row per frequency bin: f, psd, spl)
│   └── df4_OASPL               (scalar)
├── load data       {case}      (empty table — stub)
└── encoder data    {case}      (table: front, rear)
```
