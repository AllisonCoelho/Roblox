"""Textos animados em ASS (renderizados pelo libass dentro do FFmpeg).

Use *palavra* para destacar com a cor de acento. Todas as posições respeitam a zona
segura vertical (interface do TikTok/Reels/Shorts no topo, na base e na lateral direita).
"""
from __future__ import annotations

import textwrap
from pathlib import Path

# paleta do jogo (Órbita do Nexo): lilás, menta, dourado das raridades altas, rosa de alerta
CORES = {"branco": "FFFFFF", "lilas": "C9A8FF", "menta": "7CF5C8", "dourado": "FFD166", "rosa": "FF7AA8", "ciano": "7FDBFF"}


def _ass_cor(hex_rgb: str, alpha: str = "00") -> str:
    r, g, b = hex_rgb[0:2], hex_rgb[2:4], hex_rgb[4:6]
    return f"&H{alpha}{b}{g}{r}&"


def _tempo(s: float) -> str:
    s = max(0.0, s)
    h = int(s // 3600)
    m = int(s % 3600 // 60)
    return f"{h}:{m:02d}:{s % 60:05.2f}"


def _limpar(txt: str) -> str:
    return txt.replace("\\", "/").replace("{", "(").replace("}", ")").replace("\n", " ")


def _quebrar(txt: str, largura: int) -> list[str]:
    return textwrap.wrap(txt, width=largura, break_long_words=False) or [txt]


def _destacar(linha: str, acento: str, base: str = "FFFFFF") -> str:
    partes = linha.split("*")
    saida = []
    for i, p in enumerate(partes):
        if i % 2 == 1:
            saida.append("{\\c" + _ass_cor(acento) + "}" + p + "{\\c" + _ass_cor(base) + "}")
        else:
            saida.append(p)
    return "".join(saida)


class Legenda:
    def __init__(self, largura: int, altura: int, zona: dict, fonte: str = "Inter Black", fonte2: str = "Inter ExtraBold"):
        self.w, self.h, self.zona = largura, altura, zona
        self.fonte, self.fonte2 = fonte, fonte2
        self.eventos: list[str] = []

    # posições úteis --------------------------------------------------------
    @property
    def centro_x(self) -> int:
        # desloca um pouco para a esquerda por causa dos botões laterais do app
        return (self.zona["esquerda"] + (self.w - self.zona["direita"])) // 2

    def y_topo(self, deslocamento: int = 0) -> int:
        return self.zona["topo"] + 110 + deslocamento

    def y_base(self) -> int:
        return self.h - self.zona["base"] - 40

    # API -------------------------------------------------------------------
    def texto(self, txt: str, inicio: float, fim: float, *, y: int, tamanho: int = 86,
              animacao: str = "pop", acento: str = "lilas", cor: str = "branco", caixa: bool = False,
              largura_linha: int = 16, fonte: str | None = None, borda: int = 7, rotacao: float = 0.0) -> None:
        txt = _limpar(txt)
        linhas = _quebrar(txt, largura_linha)
        corpo = "\\N".join(_destacar(l, CORES.get(acento, acento), CORES.get(cor, cor)) for l in linhas)
        x = self.centro_x
        dur_ms = int((fim - inicio) * 1000)
        tags = [f"\\an5\\fn{fonte or self.fonte}\\fs{tamanho}\\bord{borda}\\shad0",
                f"\\c{_ass_cor(CORES.get(cor, cor))}\\3c&H000000&"]
        if caixa:
            tags.append(f"\\4c&H000000&\\4a&H40&\\bord{borda}\\shad0")
        if rotacao:
            tags.append(f"\\frz{rotacao:g}")
        if animacao == "pop":
            tags.append(f"\\pos({x},{y})\\fscx35\\fscy35\\t(0,110,\\fscx114\\fscy114)\\t(110,200,\\fscx100\\fscy100)\\fad(0,140)")
        elif animacao == "deslizar":
            tags.append(f"\\move({x},{y + 90},{x},{y},0,200)\\alpha&HFF&\\t(0,160,\\alpha&H00&)\\fad(0,160)")
        elif animacao == "queda":
            tags.append(f"\\move({x},{y - 140},{x},{y},0,170)\\t(170,240,\\fscy88\\fscx108)\\t(240,320,\\fscy100\\fscx100)\\fad(0,120)")
        elif animacao == "tremor":
            passos = "".join(f"\\t({i * 45},{i * 45 + 45},\\frz{(3 if i % 2 else -3) * (1 - i / 8):.1f})" for i in range(8))
            tags.append(f"\\pos({x},{y})\\fscx120\\fscy120\\t(0,90,\\fscx100\\fscy100){passos}\\fad(0,120)")
        elif animacao == "maquina":
            self._maquina(txt, inicio, fim, x, y, "".join(tags), largura_linha, acento, cor)
            return
        elif animacao == "zoom_lento":
            tags.append(f"\\pos({x},{y})\\fscx92\\fscy92\\t(0,{dur_ms},\\fscx106\\fscy106)\\fad(120,160)")
        else:
            tags.append(f"\\pos({x},{y})\\fad(80,120)")
        self.eventos.append(f"Dialogue: 0,{_tempo(inicio)},{_tempo(fim)},Padrao,,0,0,0,,{{{''.join(tags)}}}{corpo}")

    def _maquina(self, txt, inicio, fim, x, y, base_tags, largura_linha, acento, cor):
        palavras = txt.split()
        passo = min(140, int(900 / max(1, len(palavras))))
        linhas = _quebrar(txt, largura_linha)
        saida, k = [], 0
        for li, linha in enumerate(linhas):
            for pal in linha.split():
                destaque = pal.startswith("*") and pal.endswith("*")
                pal_l = pal.strip("*")
                c = CORES.get(acento) if destaque else CORES.get(cor, cor)
                saida.append("{\\alpha&HFF&\\c" + _ass_cor(c) + f"\\t({k * passo},{k * passo + 1},\\alpha&H00&)" + "}" + pal_l + " ")
                k += 1
            if li < len(linhas) - 1:
                saida.append("\\N")
        self.eventos.append(f"Dialogue: 0,{_tempo(inicio)},{_tempo(fim)},Padrao,,0,0,0,,{{{base_tags}\\pos({x},{y})\\fad(0,120)}}{''.join(saida)}")

    def selo(self, txt: str, inicio: float, fim: float, *, y: int, cor_fundo: str = "lilas", tamanho: int = 48) -> None:
        """Etiqueta com fundo colorido (ex.: '#2', 'parte 1')."""
        x = self.centro_x
        tags = (f"\\an5\\pos({x},{y})\\fn{self.fonte}\\fs{tamanho}\\c&H000000&\\3c{_ass_cor(CORES[cor_fundo])}"
                f"\\bord18\\shad0\\fscx40\\fscy40\\t(0,120,\\fscx105\\fscy105)\\t(120,200,\\fscx100\\fscy100)\\fad(0,120)")
        self.eventos.append(f"Dialogue: 1,{_tempo(inicio)},{_tempo(fim)},Padrao,,0,0,0,,{{{tags}}}{_limpar(txt)}")

    def marca_teste(self, duracao: float) -> None:
        tags = f"\\an7\\pos({self.zona['esquerda']},{self.zona['topo'] - 120})\\fn{self.fonte2}\\fs34\\c&H00FFFF&\\bord3\\alpha&H30&"
        self.eventos.append(f"Dialogue: 2,{_tempo(0)},{_tempo(duracao)},Padrao,,0,0,0,,{{{tags}}}AMOSTRA TÉCNICA · sem gameplay real · não publicar")

    def salvar(self, destino: Path) -> Path:
        cab = f"""[Script Info]
ScriptType: v4.00+
PlayResX: {self.w}
PlayResY: {self.h}
WrapStyle: 2
ScaledBorderAndShadow: yes
YCbCr Matrix: TV.709

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Padrao,{self.fonte},80,&H00FFFFFF,&H00FFFFFF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,7,0,5,0,0,0,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
        destino.write_text(cab + "\n".join(self.eventos) + "\n", encoding="utf-8")
        return destino
