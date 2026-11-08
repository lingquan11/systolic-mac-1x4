# 验证报告：systolic_row

## 1. 环境

| 项 | 内容 |
|---|---|
| 仿真器 | Icarus Verilog 14.0 (devel)，`iverilog -g2005 -Wall` 编译，`vvp -n` 运行 |
| 金标准 | `golden/gen_golden.py`（Python 3.11.6）生成的 `golden/golden_cases.vh` |
| Testbench | `tb/tb_systolic_row.v` |
| 被测设计 | `rtl/mac_pe.v`、`rtl/systolic_row.v` |
| 波形 | `sim/tb_systolic_row.vcd` |
| 运行日期 | 2026-11-08 |

## 2. 方法

- **期望值**：全部来自 Python 金标准脚本 `golden/gen_golden.py`。它按 y = Σ w_i·x_i 计算，写入 `golden/golden_cases.vh`，testbench 用 `` `include `` 读取。脚本无随机、无时间戳，重复运行输出逐字节相同（两次运行 md5 一致）。
- **激励**（每个用例）：4 拍 `w_load=1` 依次装入 w0..w3；4 拍 `x_valid=1` 依次送入 x0..x3；之后 x 送 0；等待 `done`。
- **采样**：`done` 和 `y_out` 只在时钟下降沿采样；输入也在下降沿驱动。时钟周期 10 ns。
- **判定**（三条都满足才算 PASS）：
  1. `done` 首次出现时采到的 `y_out` 等于金标准期望值；
  2. `done` 出现在送 x0 的下降沿之后第 9 个下降沿，对应规格中的 edge 8；
  3. `done` 只高 1 拍。
- **超时保护**：每个用例 50 拍内等不到 `done` 判 FAIL（TIMEOUT）；全局 20 µs 看门狗。
- **退出码**：全部通过时 `$finish`，退出码 0；有 FAIL 或全局超时时 `$fatal`，退出码 1。

## 3. 结果

| 用例 | W | x | 期望 y（Python 金标准） | 实际 y_out（仿真） | done 位置 | done 宽度 | 结论 |
|---|---|---|---|---|---|---|---|
| case0 | [1, 2, 3, 4] | [5, 6, 7, 8] | 70 | 70 | 第 9 个下降沿（edge 8） | 1 拍 | PASS |
| case1 | [255, 255, 255, 255] | [255, 255, 255, 255] | 260100 | 260100 | 第 9 个下降沿（edge 8） | 1 拍 | PASS |
| case2 | [10, 0, 7, 3] | [2, 9, 4, 1] | 51 | 51 | 第 9 个下降沿（edge 8） | 1 拍 | PASS |
| case3 | [1, 1, 1, 1] | [1, 1, 1, 1] | 4 | 4 | 第 9 个下降沿（edge 8） | 1 拍 | PASS |

case1 是满量程用例：4 × 255 × 255 = 260100。

**总结果：4/4 通过，ALL PASS。** 仿真在 690 ns 处 `$finish` 正常结束，`vvp` 退出码 0。

仿真原始输出：

```
PASS case0: y_out=70 expected=70 (done at negedge 9, width 1)
PASS case1: y_out=260100 expected=260100 (done at negedge 9, width 1)
PASS case2: y_out=51 expected=51 (done at negedge 9, width 1)
PASS case3: y_out=4 expected=4 (done at negedge 9, width 1)
----------------------------------------
SUMMARY: 4/4 passed, 0 failed
ALL PASS
tb/tb_systolic_row.v:201: $finish called at 690000 (1ps)
```

另外，case0 的流水线内部各级寄存器值已从 VCD 中逐拍提取并与手算核对一致，见 `docs/design.md` 第 3 节。

## 4. Testbench 自身的检错能力

为确认 testbench 不是"永远 PASS"，曾用 3 个故意改坏的 DUT 副本（放在临时目录，不进仓库）各跑一次：

| 注入的错误 | 结果 |
|---|---|
| `done` 晚 1 拍 | 4 个用例全部 FAIL，同时报出数值错和 done 位置错 |
| `done` 永不拉高 | 4 个用例全部 FAIL（TIMEOUT），仿真仍正常结束 |
| `y_out` 加 1 | 4 个用例全部 FAIL，打印实际值和期望值 |

注意：这组测试是在加入"失败时非零退出码"**之前**做的。加入 `$fatal` 后，只在正常设计上重跑过（退出码 0）；坏设计下退出码为 1 这条路径没有在本 testbench 上重跑，只在一个单独的小测试中确认过 `$fatal(1, …)` 会让 `vvp` 返回 1。

## 5. 未覆盖项

以下内容在 `docs/spec.md` 的验证计划中列出，但**本次没有测试**：

- 全零用例（W、x 全为 0）。
- 单热权重用例（逐个 PE 验证映射）。
- 随机用例。
- 计算中途拉低 `rst_n`。
- `y_out` 在两次 `done` 之间保持不变的显式检查（波形中可见 case0 的 `y_out` 在 done 之后保持 70，但 testbench 没有对此断言）。
- 规格允许的最小组间间隔（下一组 x0 在 edge 9 被采样）；testbench 每组之间的间隔更长。
- 综合后网表的门级仿真。

## 6. 复现

在项目根目录：

```
export PATH="/c/oss-cad-suite/bin:/c/oss-cad-suite/lib:$PATH"
iverilog -g2005 -Wall -I golden -o sim/tb_systolic_row.vvp rtl/mac_pe.v rtl/systolic_row.v tb/tb_systolic_row.v
vvp -n sim/tb_systolic_row.vvp
```

本报告的结果来自上面这组命令。也可以一条命令完成：

```
bash sim/run.sh
```

`sim/run.sh` 依次重新生成金标准、编译、仿真，自动设置 `PATH`，并把 `vvp` 的退出码原样返回（0 = ALL PASS）。用户已单独运行过一次，结果与上面完全一致：4/4 PASS、ALL PASS、`run.sh: PASS (exit 0)`。

注意：手动执行时，oss-cad-suite 的 `lib/` 不在 `PATH` 上会导致 `vvp` 段错误。
