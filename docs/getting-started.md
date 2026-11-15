# 上手指南：第一次跑通仿真和综合

回到 [项目首页](../README.md)。首页有设计概要、接口表、目录和结果索引。本指南只讲怎样在**现有仓库**上做第一次仿真和综合，按下面的顺序读：

1. [前置条件](#1-前置条件)
2. [安装与检查](#2-安装与检查)
3. [第一次仿真](#3-第一次仿真)
4. [查看结果](#4-查看结果)
5. [综合](#5-综合)
6. [故障排查](#6-故障排查)
7. [本次核对的边界](#7-本次核对的边界)

不在这里改 RTL，也不做 4×4。规格原文见 [spec.md](spec.md)，实现说明见 [design.md](design.md)。

## 1. 前置条件

需要：

- bash。仓库脚本使用 `BASH_SOURCE`，要用 `bash sim/run.sh` 这种调用。
- Python 3，命令名是 `python3`。脚本只用标准库，并加上 `-I`（隔离模式）。
- Icarus Verilog：`iverilog` 和 `vvp`。
- Yosys：`yosys`。

不需要商业 EDA、工艺库、FPGA 板或波形查看器。本次没有打开图形界面。

脚本会自己切到仓库根目录。在仓库根执行 `bash sim/run.sh`，或在别的目录执行 `bash /仓库路径/sim/run.sh`，都可以。本次两种调用都跑过。

被仿真的顶层是 `systolic_row`，端口见首页的接口表，源码是 [rtl/systolic_row.v](../rtl/systolic_row.v)。testbench 在 [tb/tb_systolic_row.v](../tb/tb_systolic_row.v)：时钟周期 10 ns，输入在下降沿驱动。它检查三件事：`y_out` 等于金标准、`done` 出现在送出 x0 的下降沿之后第 9 个下降沿、`done` 只高 1 拍。第 9 个下降沿对应规格里的 edge 8（采到 x0 的上升沿记为第 0 拍）。

## 2. 安装与检查

### 2.1 脚本怎样寻找工具

[sim/run.sh](../sim/run.sh) 和 [synth/run_synth.sh](../synth/run_synth.sh) 都有这一段：

```bash
OSS_CAD="${OSS_CAD:-/c/oss-cad-suite}"
if [ -d "$OSS_CAD/bin" ]; then
    export PATH="$OSS_CAD/bin:$OSS_CAD/lib:$PATH"
fi
```

未设置环境变量 `OSS_CAD` 时，默认字符串是 `/c/oss-cad-suite`。只有 `$OSS_CAD/bin` 这个目录真的存在，脚本才把该目录的 `bin` 和 `lib` 放到 `PATH` 前面。目录不存在时，脚本不改 `PATH`，直接使用当前 shell 里已经能找到的 `python3`、`iverilog`、`vvp`、`yosys`。

`/c/oss-cad-suite` 是 Git Bash 对 Windows 路径 `C:\oss-cad-suite` 的写法。仓库 [synth/out/yosys.log](../synth/out/yosys.log) 里有 `C:\oss-cad-suite\bin\../share/yosys/techmap.v`，同一份日志的编译器字符串是 `x86_64-w64-mingw32-g++`。这两处表明入库的那次综合跑在 Windows 上，OSS CAD Suite 位于 `C:\oss-cad-suite`。

整理本指南时没有 Windows 环境，没有重新执行 `C:\oss-cad-suite` 或 `/c/oss-cad-suite`。第 2.2 节和第 2.3 节里写出完整命令的步骤，是在 Ubuntu 24.04.5 上跑过的；其中关于 Windows 安装包的句子单独标了未执行。

### 2.2 做法 A：Ubuntu 发行版软件包

本次机器上原来没有 `iverilog` 和 `yosys`，`/c/oss-cad-suite` 也不存在。执行过：

```bash
sudo apt-get update
sudo apt-get install -y iverilog yosys
```

装好后的版本是：

| 命令 | 本次输出的版本行 |
|---|---|
| `python3 --version` | Python 3.12.3 |
| `iverilog -V` | Icarus Verilog version 12.0 (stable) |
| `vvp -V` | Icarus Verilog runtime version 12.0 (stable) |
| `yosys -V` | Yosys 0.33 (git sha1 2584903a060) |
| `bash --version` | GNU bash, version 5.2.21(1)-release (x86_64-pc-linux-gnu) |

检查时看命令能否打印出版本，而不是只看有没有报错。`/bin/sh` 在这台机器上指向 dash。不要用 `sh` 去跑脚本，见第 6 节。

不设置 `OSS_CAD` 时，脚本发现默认目录不存在，就用 `/usr/bin` 里的这些工具。仿真可以与验证报告对齐；综合的单元个数与仓库记录不同，见第 5 节。

### 2.3 做法 B：OSS CAD Suite，并设置 OSS_CAD

仓库报告使用的 Yosys 是 0.70+360（git sha1 `5e740962d`）。本次下载并解压了 2026-11-08 的 Linux 包 `oss-cad-suite-linux-x64-20261108.tgz`，发布页是 <https://github.com/YosysHQ/oss-cad-suite-build/releases/tag/2026-11-08>。解压后设置的是实际目录，例如：

```bash
export OSS_CAD=/实际解压目录/oss-cad-suite
```

本次即使 `PATH` 里还有做法 A 的 Yosys 0.33，脚本仍会把 `$OSS_CAD/bin:$OSS_CAD/lib` 放在前面。用 `bash -x` 看过这条 `PATH`，随后的 `iverilog`、`vvp`、`yosys` 来自该套件。版本是：

- Yosys 0.70+360（git sha1 `5e740962d`，Release，Clang）。版本号和 git sha1 与仓库 `yosys.log` 相同；仓库日志里的编译器是 mingw g++，本次是 Clang。
- Icarus Verilog 14.0 (devel)（`s20260301-871-g66f0e8a19-dirty`）。验证报告写的仿真器是 Icarus Verilog 14.0 (devel)。
- `python3` 仍是系统的 Python 3.12.3。这个 Linux 包的 `bin` 目录里没有 `python3`。

仓库脚本不会 `source` OSS CAD Suite 自带的 `environment`。本次没有单独测试「先 `source environment` 再跑脚本」。按本指南，设置 `OSS_CAD` 后直接运行第 3 节和第 5 节的命令。

Windows 安装包本次没有下载，也没有运行。若以后在 Git Bash 里使用，并且套件就装在 `C:\oss-cad-suite`，脚本默认的 `/c/oss-cad-suite` 会指向那里。这是脚本写法和仓库日志能够对上的说明，不是本次执行过的步骤。

## 3. 第一次仿真

在仓库根目录执行：

```bash
bash sim/run.sh
```

脚本依次做三件事：

1. `python3 -I golden/gen_golden.py`，重写 [golden/golden_cases.vh](../golden/golden_cases.vh)。
2. `iverilog -g2005 -Wall -I golden -o sim/tb_systolic_row.vvp rtl/mac_pe.v rtl/systolic_row.v tb/tb_systolic_row.v`。
3. `vvp -n sim/tb_systolic_row.vvp`。

成功时进程退出码为 0。终端里确认：

```bash
echo $?
```

## 4. 查看结果

做法 A 和做法 B 本次都打印了下面这段正文。它与 [verification_report.md](verification_report.md) 第 3 节保存的仿真输出一致。`690000 (1ps)` 就是 690 ns。

```text
PASS case0: y_out=70 expected=70 (done at negedge 9, width 1)
PASS case1: y_out=260100 expected=260100 (done at negedge 9, width 1)
PASS case2: y_out=51 expected=51 (done at negedge 9, width 1)
PASS case3: y_out=4 expected=4 (done at negedge 9, width 1)
----------------------------------------
SUMMARY: 4/4 passed, 0 failed
ALL PASS
tb/tb_systolic_row.v:201: $finish called at 690000 (1ps)
run.sh: PASS (exit 0)
```

四个期望值来自 [golden/gen_golden.py](../golden/gen_golden.py)：

| 用例 | W | x | y |
|---|---|---|---|
| case0 | 1, 2, 3, 4 | 5, 6, 7, 8 | 70 |
| case1 | 255, 255, 255, 255 | 255, 255, 255, 255 | 260100 |
| case2 | 10, 0, 7, 3 | 2, 9, 4, 1 | 51 |
| case3 | 1, 1, 1, 1 | 1, 1, 1, 1 | 4 |

本次用 Python 3.12.3 重写的 `golden_cases.vh` 与仓库文件逐字节相同。验证报告里的 Python 版本是 3.11.6；那个解释器本次没有再安装。

波形默认写到仓库根下的 [sim/tb_systolic_row.vcd](../sim/tb_systolic_row.vcd)。仓库里的这份文件是 CRLF。做法 B 在 Linux 上生成的是 LF；去掉 `$date` 段并把 CRLF 换成 LF 之后，与仓库波形逐字节相同。做法 A（Icarus 12.0）的波形在同样处理之后仍与仓库文件不同，四条用例的 PASS 判定不变。本次没有用 GTKWave 或其他图形界面打开 VCD。

[design.md](design.md) 第 3 节的逐拍表，是原先从仓库波形抽出的 case0。本次没有重新从 VCD 抄那张表。

`ALL PASS` 只覆盖 testbench 里的这 4 个用例。验证报告第 5 节列出的全零、单热、随机、中途复位、组间最小间隔和门级仿真，这次都没有测。

仿真会重写本仓库里的 `golden/golden_cases.vh`、`sim/tb_systolic_row.vvp` 和 `sim/tb_systolic_row.vcd`。本次复跑在临时副本里做，没有把这些文件提交回去。`vvp` 是本机编译结果，本次没有要求它和仓库里的文件逐字节相同。

## 5. 综合

在仓库根目录执行：

```bash
bash synth/run_synth.sh
```

脚本先运行：

```bash
yosys -q -l synth/out/yosys.log -s synth/synth.ys
```

`synth.ys` 读 [rtl/mac_pe.v](../rtl/mac_pe.v) 和 [rtl/systolic_row.v](../rtl/systolic_row.v)，顶层是 `systolic_row`，做 `synth -flatten`，并检查锁存器和组合环。然后 `python3 -I synth/make_report.py` 把报告写到 [synth/synth_report.txt](../synth/synth_report.txt)。

成功时最后一行是：

```text
run_synth.sh: PASS (no latches, no combinational loops)
```

退出码为 0。

仓库记录（Windows 上的 Yosys 0.70+360，见 [synthesis_report.md](synthesis_report.md) 和 [synth/synth_report.txt](../synth/synth_report.txt)）：

| 项 | 记录值 |
|---|---|
| 总单元 | 1859（1855 个逻辑或触发器单元，另 4 个 `$scopeinfo`） |
| 触发器 | 227（`$_DFF_PN0_` 174 个，`$_DFFE_PN0P_` 53 个） |
| 锁存器 | 0 |
| 组合环 | 0（`Found 0 SCCs`） |
| `check -assert` | 0 个问题 |
| yosys 警告 | 0 |

本次复跑：

| 环境 | 本次看到的结果 |
|---|---|
| 做法 B，Yosys 0.70+360（git sha1 `5e740962d`） | 生成的 `synth/synth_report.txt` 与仓库文件逐字节相同。`synth/out/stat.txt`、`scc.txt`、`check.txt` 的正文在把 CRLF 换成 LF 之后也与仓库相同。仓库这三份是 CRLF，本次 Linux 输出是 LF。`yosys.log` 不是同一份文件：仓库日志里的工具路径是 `C:\oss-cad-suite\...`，本次是 Linux 解压路径，编译器字符串也不同。 |
| 做法 A，Yosys 0.33（git sha1 `2584903a060`） | 退出码同样是 0，触发器仍是 227，锁存器 0，组合环 0，警告 0。总单元数是 2003，没有 `$scopeinfo`。报告里按 RTL 寄存器对账的那一节，与仓库报告第 3 节相同。 |

1859 是仓库记录。2003 是 Yosys 0.33 这一次的结果。两套数字都来自真实运行，对应不同版本。没有工艺库，单元个数不能换成面积、时序或功耗。

综合会重写 `synth/synth_report.txt` 和 `synth/out/`。在 Yosys 0.33 上重跑之后，工作区里的报告会变成 2003 那一版。本次没有把复跑产物提交回仓库。

## 6. 故障排查

前四条是本次在 Ubuntu 24.04.5 上、从仓库根执行对应命令时看到的终端输出。后面几条写明了哪些来自脚本原文、哪些本次没有跑到。

### 用了 `sh` 而不是 `bash`

在仓库根执行 `sh sim/run.sh` 时，`/bin/sh`（dash）打印：

```text
sim/run.sh: 12: Bad substitution
== [1/3] golden ==
python3: can't open file '//golden/gen_golden.py': [Errno 2] No such file or directory
run.sh: golden generation failed
```

退出码 2。第 12 行用了 bash 的 `BASH_SOURCE`。改成 `bash sim/run.sh`。

### 找不到 `python3`

```text
== [1/3] golden ==
sim/run.sh: line 25: python3: command not found
run.sh: golden generation failed
```

退出码 2。安装 Python 3，并确认命令名是 `python3`。若可执行文件不叫这个名字，先 `export PYTHON=实际命令`。脚本读的是 `PYTHON`，默认 `python3`。

### 找不到 `iverilog`

金标准会先生成成功，然后：

```text
== [2/3] compile ==
sim/run.sh: line 28: iverilog: command not found
run.sh: compile failed
```

退出码 3。按第 2 节安装 Icarus Verilog，或设置 `OSS_CAD` 指向带 `bin/iverilog` 的套件。`vvp` 要和 `iverilog` 来自同一套工具。

### 找不到 `yosys`

```text
== [1/2] yosys ==
synth/run_synth.sh: line 23: yosys: command not found
run_synth.sh: yosys failed (see synth/out/yosys.log)
```

退出码 2。本次在一个空的 `synth/out/` 上重试：脚本会创建这个目录，但 yosys 没有启动，所以目录里没有 `yosys.log`。终端里的 `yosys: command not found` 就是原因。提示里的日志路径要等 yosys 真正跑起来之后才有新内容。

### 仿真没有打印 `ALL PASS`

[sim/run.sh](../sim/run.sh) 在 `vvp` 返回非 0 时会打印 `run.sh: FAIL (vvp exit N)`，并把这个退出码原样返回。testbench 源码里，有失败时调用 `$fatal`。验证报告第 4 节写过：这条非零退出码没有在三份故意改坏的设计上重跑。本次也没有再造坏设计，所以终端里没有新的 FAIL 样例，不能把上面那行失败文案当成这次亲眼看到的输出。若真的出现 `FAIL case` 或 `TIMEOUT`，先对照第 4 节的期望文本和 [verification_report.md](verification_report.md)，把终端输出留着。先查环境和期望值，再决定要不要改设计。

### 综合单元数不是 1859

做法 A 的 Yosys 0.33 本次得到的就是 2003，同时仍然打印 `run_synth.sh: PASS`。这是版本差异。要和仓库里的 1859 对齐，本次用的是第 2.3 节的 Yosys 0.70+360。对齐之后也不要把单元个数写成面积或时序。

### 验证报告里的 `vvp` 段错误，本次没有复现

[verification_report.md](verification_report.md) 第 6 节写过：手动把 oss-cad-suite 放进 `PATH` 时如果漏了 `lib/`，`vvp` 会段错误。那里的路径是 `/c/oss-cad-suite/bin` 和 `/c/oss-cad-suite/lib`。

本次在 Linux 的 2026-11-08 套件上做了对照：只把 `bin` 放进 `PATH`，不把 `lib` 放进 `PATH`，并且 `OSS_CAD` 指到一个不存在的目录，让脚本不要自己再改 `PATH`。`bash sim/run.sh` 仍然是 `ALL PASS`，退出码 0。该套件 Linux 版的 `bin/vvp` 是包装脚本，自己用 `lib/ld-linux` 指定库路径。因此「漏了 `lib` 就一定会段错误」不能写成这次 Linux 环境的结论。仓库脚本在找到 `$OSS_CAD/bin` 时仍会同时加上 `lib`。

### 规格文首状态已订正

[spec.md](spec.md) 开头原写「草案，待确认（确认前不写 RTL）」，现已订正为「已实现」。[rtl/systolic_row.v](../rtl/systolic_row.v) 和 [rtl/mac_pe.v](../rtl/mac_pe.v) 已经在仓库里，原状态句与现状不符。

## 7. 本次核对的边界

整理本指南时，由 Grok 在 Ubuntu 24.04.5 的临时副本里运行了现有脚本。仓库中的 RTL、testbench、构建脚本和已入库结果都没有被修改，临时产物也没有提交。

核对过的内容：

- 做法 A：`bash sim/run.sh`、`bash synth/run_synth.sh`，退出码都是 0。
- 做法 B：设置 `OSS_CAD` 后同样两条命令；`bash -x` 确认套件被放到 `PATH` 前面。综合报告与仓库 `synth/synth_report.txt` 逐字节相同。
- Python 3.12.3 生成的 `golden_cases.vh` 与仓库逐字节相同。
- 做法 B 的 VCD 在去掉 `$date`、并把 CRLF 换成 LF 之后，与仓库波形逐字节相同。
- `sh sim/run.sh`，以及缺少 `python3`、`iverilog`、`yosys` 时的终端输出和退出码。
- Linux 套件只把 `bin` 放进 `PATH` 时，仿真仍然通过。

没有核对的内容：

- Windows、Git Bash、WSL、macOS，以及 `C:\oss-cad-suite` 的重新执行。
- `source` OSS CAD Suite 的 `environment` 之后再跑脚本。
- 用 GTKWave 或任何图形界面打开波形。
- 重做验证报告第 4 节的三份坏设计，或从 VCD 重抄设计说明第 3 节的逐拍表。
- 门级仿真、工艺库、面积、时序、功耗、芯片实测。
- 验证报告所写的 Python 3.11.6。本次金标准是用 Python 3.12.3 生成的，文件内容与仓库一致。

命令通过，只说明这些脚本在上述 Linux 环境里得到了第 4 节和第 5 节的输出。它不代替我在自己机器上的操作，也不表示我已经掌握安装、仿真或综合。
