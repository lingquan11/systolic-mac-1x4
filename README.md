# systolic-mac-1x4

我的第一个数字 IC 前端练习：用 Verilog 写一个 1×4 脉动阵列行，计算 4 维无符号内积 `y = w0·x0 + w1·x1 + w2·x2 + w3·x3`。权重预载后停在各个处理单元（PE）里，x 从左端逐拍流入。

仓库里有规格、RTL、4 个定向用例的仿真记录，以及不绑工艺库的逻辑综合记录。这些记录说明这一版 1×4 设计在现有 testbench 和通用综合下跑过；它们不包含面积、时序、功耗或芯片实测，也不表示我已经掌握这条流程。

## 从这里开始

逐步安装、第一次仿真、查看输出、综合和排错，只走这一份：[上手指南](docs/getting-started.md)。

工具已经能在 shell 里找到时，指南里要跑的两条命令是 `bash sim/run.sh` 和 `bash synth/run_synth.sh`。安装检查、期望输出和报错都写在指南里。

规格、设计说明、验证报告和综合报告供第一次跑通之后对照。

## 设计概要

4 个 MAC PE 排成一行。`w_load` 连续有效 4 拍时，按 PE0 到 PE3 装入 w0..w3。一组 x 必须连续 4 拍给 `x_valid=1`，顺序是 x0..x3。每个 PE 的 x 走 1 级寄存器，部分和走 2 级寄存器，所以 x 比部分和快一倍，按自然顺序送入就能在每个 PE 对齐。以采到 x0 的上升沿为第 0 拍，`done` 在第 8 拍拉高，只持续 1 拍，这一拍的 `y_out` 有效，并保持到下一组 `done`。`rst_n` 是低有效异步复位。一次只算一组。

```
w_in[7:0] ── w_load 有效时依次写入 PE0..PE3 的权重寄存器

x_in[7:0] ── x_valid=0 时改为 0 ──► PE0 ──► PE1 ──► PE2 ──► PE3
                                      │psum   │psum   │psum   │psum
                                      ▼       ▼       ▼       ▼
                                   done 那一拍把 y_out[23:0] 写成 w0·x0 + w1·x1 + w2·x2 + w3·x3
                                   done：采到 x0 之后的第 8 拍，脉冲宽度 1 拍
```

更细的结构、逐拍数据流和时序表在 [docs/design.md](docs/design.md)。拍级规格在 [docs/spec.md](docs/spec.md)。`docs/spec.md` 文首仍写着「草案，待确认（确认前不写 RTL）」；RTL 已经在仓库里，本次没有改规格文件。

## 顶层接口

模块 `systolic_row`，源码 [rtl/systolic_row.v](rtl/systolic_row.v)。默认参数 `DATA_W=8`、`ACC_W=24`。PE 个数是模块内部的 `localparam N = 4`，不是端口参数。单个 PE 的端口在 [rtl/mac_pe.v](rtl/mac_pe.v)。

| 信号 | 方向 | 位宽 | 说明 |
|---|---|---|---|
| `clk` | in | 1 | 上升沿采样 |
| `rst_n` | in | 1 | 异步复位，低有效 |
| `w_load` | in | 1 | 为 1 的时钟沿装入一拍权重 |
| `w_in` | in | 8 | 权重，顺序 w0、w1、w2、w3 |
| `x_in` | in | 8 | 输入数据，顺序 x0、x1、x2、x3 |
| `x_valid` | in | 1 | 为 1 时 `x_in` 有效；为 0 时送进 PE0 的 x 被置 0 |
| `y_out` | out | 24 | `done` 为 1 的那一拍更新，之后保持 |
| `done` | out | 1 | 结果有效脉冲，宽 1 拍 |

8 个端口的位宽相加是 45，与仓库综合统计里的 `45 port bits` 一致（见 [synth/out/stat.txt](synth/out/stat.txt)）。满量程 4×255×255 = 260100，小于 2^24。这个数是 case1 的期望值，也写在规格里。

## 目录

| 路径 | 内容 |
|---|---|
| [rtl/](rtl/) | `mac_pe.v`、`systolic_row.v` |
| [tb/](tb/) | 自检 testbench `tb_systolic_row.v` |
| [golden/](golden/) | `gen_golden.py` 和它生成的 `golden_cases.vh` |
| [sim/](sim/) | `run.sh`，以及已入库的波形 `tb_systolic_row.vcd` |
| [synth/](synth/) | `run_synth.sh`、`synth.ys`、`synth_report.txt`；`out/` 是工具原始产出 |
| [docs/](docs/) | 上手指南、规格、设计说明、验证报告、综合报告 |

## 记录里的结果

仿真：4 个定向用例都是 PASS，终端结尾是 `ALL PASS`，`$finish` 在 690 ns。用例期望值是 70、260100、51、4。原始输出和未测项在 [docs/verification_report.md](docs/verification_report.md)。波形文件是 [sim/tb_systolic_row.vcd](sim/tb_systolic_row.vcd)；case0 的逐拍表在设计说明第 3 节，那是当时从波形里抽出的，本次整理文档时没有重新抄表。

综合：仓库报告记的是 1859 个单元、227 个触发器、0 个锁存器、0 个组合环、0 条 yosys 警告。RTL 寄存器共 292 位；少掉的 65 位里，57 位是部分和高位被判成恒 0，8 位是 PE3 的 `x_out` 没有负载。对账表在 [docs/synthesis_report.md](docs/synthesis_report.md)，工具原文在 [synth/synth_report.txt](synth/synth_report.txt)。这是通用综合，没有工艺库，不能从单元个数读出面积、时序或功耗。

这些数字以仓库里的报告为准。不同 Yosys 版本重跑时单元个数会变；同版本复跑是否对得上，写在上手指南第 5 节。

## 局限

- 没有工艺库，因此没有面积、时序和功耗数字。
- 没有做综合后网表的门级仿真。
- 验证计划里还有全零、单热权重、随机向量、计算中途复位等项，这次的 testbench 没有覆盖。清单在验证报告第 5 节。
- 没有芯片实测。
- 下一步想把这一行扩成 4×4，做矩阵乘矩阵。仓库里还没有这部分 RTL，本次也没有补。

## 协作

代码、脚本和原有报告是协作完成的，文档入口是后来补上的。署名如下。

- 规格和几项关键决定是我定的：部分和用两级寄存器做时序对齐、数据用无符号、一次算一组、复位用异步低有效。
- `rtl/`、`tb/`、`golden/`、`sim/`、`synth/` 里的代码和脚本，以及 `docs/spec.md`、`docs/design.md`、`docs/verification_report.md`、`docs/synthesis_report.md` 的初稿，是 Claude Code 写的。我逐项看过。验证报告写明我曾单独跑过一次 `bash sim/run.sh`，结果与报告中的输出一致。
- 验证报告第 4 节记录了三份故意改坏的设计，用来看 testbench 会不会报 FAIL。同一节也写了限制：加上 `$fatal` 之后，退出码 1 这条路径没有在那三份坏设计上重跑。
- 本页和 [docs/getting-started.md](docs/getting-started.md) 是我请 Grok 根据已有规格、RTL、脚本和报告整理的，用来补上「从哪里开始、怎样第一次跑通」。Grok 没有改 RTL、testbench、脚本和结果文件。整理时在 Linux 上复跑了现有命令，范围和未核对的部分写在指南末尾。

代码、脚本和上述文档都不能写成我的独立实现。仿真或综合退出码为 0，只说明当时那条命令在对应环境下通过了检查。

## 许可

MIT License。版权声明是 Copyright (c) 2026 lingquan11，全文见 [LICENSE](LICENSE)。
