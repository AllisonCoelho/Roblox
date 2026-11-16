-- Identidade visual "Tinta e Selo": preto-tinta, papel e vermelho de carimbo.
-- As cores neon ficam reservadas para as raridades das auras (Auras.Tiers).
local Tema = {}

Tema.Cores = {
	-- Paleta principal
	Tinta = Color3.fromHex("0B0A10"),
	TintaClara = Color3.fromHex("15131D"),
	Borda = Color3.fromHex("3A3546"),
	Papel = Color3.fromHex("F2EDE4"),
	Selo = Color3.fromHex("E2233B"),
	SeloEscuro = Color3.fromHex("4A1520"),
	TextoSuave = Color3.fromHex("A9A3B6"),
	Ouro = Color3.fromHex("FFC83D"),
	Branco = Color3.new(1, 1, 1),

	-- Nomes usados pelos componentes genéricos (Componentes/Navegacao)
	Contorno = Color3.fromHex("0B0A10"),
	Fundo = Color3.fromHex("0B0A10"),
	Creme = Color3.fromHex("15131D"), -- fundo dos painéis
	Vermelho = Color3.fromHex("E2233B"),
	VermelhoClaro = Color3.fromHex("F0505F"),
	OuroClaro = Color3.fromHex("FFE08A"),
	OuroEscuro = Color3.fromHex("B07800"),
	Menta = Color3.fromHex("5BE37D"),
	MentaClaro = Color3.fromHex("9AF0B0"),
	RosaEscuro = Color3.fromHex("A0182B"),
	Uva = Color3.fromHex("A855F7"),
	UvaClaro = Color3.fromHex("C69BFA"),
	Cinza = Color3.fromHex("5E586B"),
	CinzaClaro = Color3.fromHex("A9A3B6"),
}

-- Pares (claro, base) usados nos degradês dos botões genéricos
Tema.Botoes = {
	selo = { Color3.fromHex("F0505F"), Tema.Cores.Selo },
	vermelho = { Color3.fromHex("F0505F"), Tema.Cores.Selo },
	papel = { Tema.Cores.Papel, Tema.Cores.Papel },
	tinta = { Tema.Cores.TintaClara, Tema.Cores.Tinta },
	cinza = { Color3.fromHex("8A8496"), Tema.Cores.Cinza },
	verde = { Tema.Cores.MentaClaro, Tema.Cores.Menta },
	roxo = { Tema.Cores.UvaClaro, Tema.Cores.Uva },
}

-- Oswald (títulos estreitos, cara de anime) e Permanent Marker (pincel)
Tema.Fonte = Enum.Font.Oswald
Tema.FonteTexto = Enum.Font.Oswald
Tema.FonteNegrito = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
Tema.FonteMedia = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Medium)
Tema.FontePincel = Font.new("rbxasset://fonts/families/PermanentMarker.json")

Tema.Contorno = 3
Tema.Canto = 10
Tema.Sombra = 5

-- Tamanho de referência das telas de design; a interface escala a partir dele
Tema.Referencia = Vector2.new(1600, 900)

-- Padrão de interface Órbita do Nexo.
Tema.Orbita = {
	Fundo = Color3.fromHex("0B0915"),
	Painel = Color3.fromHex("141126"),
	Elevado = Color3.fromHex("211C37"),
	Borda = Color3.fromHex("605682"),
	Lilas = Color3.fromHex("C0ADFF"),
	Menta = Color3.fromHex("B7FFD9"),
	Texto = Color3.fromHex("F7F2EC"),
	TextoSuave = Color3.fromHex("C9C7D6"),
	Foco = Color3.fromHex("E5D9FF"),
	Aviso = Color3.fromHex("FF8298"),
	Ativo = Color3.fromHex("17312F"),
}

Tema.FonteCorpo = Font.fromEnum(Enum.Font.BuilderSans)
Tema.FonteNumeros = Font.fromEnum(Enum.Font.RobotoMono)

return Tema
