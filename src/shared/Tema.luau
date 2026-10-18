-- Paleta, fontes e medidas da interface (ver docs/design/01-identidade.png)
local Tema = {}

Tema.Cores = {
	Contorno = Color3.fromHex("2B1B3D"),
	Rosa = Color3.fromHex("FF5FA2"),
	RosaClaro = Color3.fromHex("FF8CC0"),
	RosaEscuro = Color3.fromHex("D63384"),
	Menta = Color3.fromHex("3DDC97"),
	MentaClaro = Color3.fromHex("7FF0BD"),
	MentaEscuro = Color3.fromHex("1FA36B"),
	Ouro = Color3.fromHex("FFC83D"),
	OuroClaro = Color3.fromHex("FFE08A"),
	OuroEscuro = Color3.fromHex("E09B00"),
	Ceu = Color3.fromHex("4CC9F0"),
	CeuClaro = Color3.fromHex("86DCF7"),
	Uva = Color3.fromHex("8B5CF6"),
	UvaClaro = Color3.fromHex("A98BFF"),
	Laranja = Color3.fromHex("FF8A3D"),
	LaranjaClaro = Color3.fromHex("FFAD73"),
	Vermelho = Color3.fromHex("FF3B3B"),
	VermelhoClaro = Color3.fromHex("FF8A8A"),
	Cinza = Color3.fromHex("9A8FAB"),
	CinzaClaro = Color3.fromHex("CFC6DA"),
	Creme = Color3.fromHex("FFF7EC"),
	Lilas = Color3.fromHex("F3EBF8"),
	LilasTexto = Color3.fromHex("D9C9F2"),
	TextoSuave = Color3.fromHex("7A6A8C"),
	Fundo = Color3.fromHex("1A1026"),
	Branco = Color3.new(1, 1, 1),
}

-- Pares (claro, base) usados nos degradês dos botões
Tema.Botoes = {
	verde = { Tema.Cores.MentaClaro, Tema.Cores.Menta },
	rosa = { Tema.Cores.RosaClaro, Tema.Cores.Rosa },
	azul = { Tema.Cores.CeuClaro, Tema.Cores.Ceu },
	roxo = { Tema.Cores.UvaClaro, Tema.Cores.Uva },
	ouro = { Tema.Cores.OuroClaro, Tema.Cores.Ouro },
	laranja = { Tema.Cores.LaranjaClaro, Tema.Cores.Laranja },
	vermelho = { Tema.Cores.VermelhoClaro, Tema.Cores.Vermelho },
	cinza = { Tema.Cores.CinzaClaro, Tema.Cores.Cinza },
	ardosia = { Color3.fromHex("8F80A8"), Color3.fromHex("5E4F78") },
}

Tema.Fonte = Enum.Font.FredokaOne
Tema.FonteTexto = Enum.Font.BuilderSansBold

Tema.Contorno = 4
Tema.Canto = 18
Tema.Sombra = 6

-- Tamanho de referência das telas de design; a interface escala a partir dele
Tema.Referencia = Vector2.new(1600, 900)

return Tema
