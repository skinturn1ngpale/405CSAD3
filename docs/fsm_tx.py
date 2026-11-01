# Діаграма станів (FSM) передавача SPI Master -> fsm_tx.png
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Ellipse, FancyArrowPatch
plt.rcParams["font.family"] = "DejaVu Sans"
fig, ax = plt.subplots(figsize=(8.2, 6.2), dpi=160)
ax.set_xlim(0, 8.2); ax.set_ylim(-0.7, 6.3); ax.axis("off")
N = {"S_IDLE": (1.5, 4.2, "ss_n = 1\nclk_en = 0"), "S_SETUP": (6.7, 4.2, "ss_n = 0\nclk_en = 0"),
     "S_SHIFT": (6.7, 1.4, "clk_en = 1\nSCK тактується"), "S_HOLD": (1.5, 1.4, "clk_en = 0\nSCK у спокої")}
RX, RY = 1.05, 0.72
for k, (x, y, t) in N.items():
    ax.add_patch(Ellipse((x, y), 2*RX, 2*RY, fc="#e8f0fe", ec="#1a4f8b", lw=1.8, zorder=2))
    ax.text(x, y + 0.2, k, ha="center", va="center", fontsize=11, weight="bold", zorder=3)
    ax.text(x, y - 0.2, t, ha="center", va="center", fontsize=8.5, zorder=3)
def arrow(p, q, rad=0.0):
    ax.add_patch(FancyArrowPatch(p, q, arrowstyle="-|>", mutation_scale=14, lw=1.4, color="#222",
                                 connectionstyle=f"arc3,rad={rad}", zorder=1))
def loop(x, y, up=True, w=0.42):
    s = 1 if up else -1
    arrow((x - w, y + s*RY*0.93), (x + w, y + s*RY*0.93), rad=-1.7*s)
t = lambda x, y, s, **k: ax.text(x, y, s, fontsize=8.5, ha=k.get("ha", "center"), va=k.get("va", "center"), linespacing=1.25)
# rst -> IDLE
arrow((0.2, 5.3), (0.95, 4.75)); t(0.2, 5.55, "rst = 1", ha="left")
# IDLE -> SETUP
arrow((N["S_IDLE"][0] + RX, 4.2), (N["S_SETUP"][0] - RX, 4.2))
t(4.1, 4.62, "start = 1: ss_n <= 0,\nзавантаження shreg,\nbit_cnt = 0")
# SETUP -> SHIFT
arrow((6.7, 4.2 - RY), (6.7, 1.4 + RY)); t(7.05, 2.8, "tmr = CLK_DIV-1", ha="left")
# SHIFT -> HOLD
arrow((N["S_SHIFT"][0] - RX, 1.4), (N["S_HOLD"][0] + RX, 1.4))
t(4.1, 1.78, "trail_stb = 1 і bit_cnt = N-1\n(віддано N бітів)")
# HOLD -> IDLE
arrow((1.5, 1.4 + RY), (1.5, 4.2 - RY)); t(1.2, 2.8, "tmr = CLK_DIV-1:\nss_n <= 1, done <= 1", ha="right")
# self loops
loop(*N["S_IDLE"][:2]); t(1.5, 5.95, "start = 0")
loop(*N["S_SETUP"][:2]); t(6.7, 5.95, "tmr < CLK_DIV-1:  tmr++")
loop(*N["S_SHIFT"][:2], up=False); t(6.7, -0.45, "shift_stb: mosi <= MSB, зсув shreg\ntrail_stb: bit_cnt++")
loop(*N["S_HOLD"][:2], up=False); t(1.5, -0.45, "tmr < CLK_DIV-1:  tmr++")
plt.tight_layout(pad=0.3); plt.savefig("fsm_tx.png", facecolor="white")
