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

-- Padrão de interface "Nexo Vibrante": cores saturadas, contorno escuro grosso, cantos
-- arredondados e fonte arredondada (estilo dos jogos de aventura do Roblox, com identidade própria).
-- Os nomes das chaves continuam os mesmos para todas as telas herdarem o visual novo.
Tema.Orbita = {
	Fundo = Color3.fromHex("10153A"), -- texto sobre o destaque e fundo profundo
	Painel = Color3.fromHex("2A3A8F"), -- azul real dos painéis
	Elevado = Color3.fromHex("3A50B8"), -- blocos dentro dos painéis
	Borda = Color3.fromHex("0B0F26"), -- contorno grosso
	Lilas = Color3.fromHex("FFC83D"), -- destaque principal (ouro)
	Menta = Color3.fromHex("5BF07D"),
	Texto = Color3.fromHex("FFFFFF"),
	TextoSuave = Color3.fromHex("C9D4FF"),
	Foco = Color3.fromHex("FFFFFF"),
	Aviso = Color3.fromHex("FF4D6D"),
	Ativo = Color3.fromHex("1E8A43"),
}

-- Cores dos botões do menu lateral e da hotbar (cada atalho tem a sua)
Tema.Vibrante = {
	Loja = { Color3.fromHex("FFB020"), Color3.fromHex("FF7A00") },
	Bolsa = { Color3.fromHex("FF8A3D"), Color3.fromHex("E2462B") },
	Indice = { Color3.fromHex("4FC3FF"), Color3.fromHex("2B6BFF") },
	Temporada = { Color3.fromHex("FF6FD0"), Color3.fromHex("B23BFF") },
	Ajustes = { Color3.fromHex("A9B4D6"), Color3.fromHex("5F6B91") },
	Auto = { Color3.fromHex("6CF08A"), Color3.fromHex("1FAE4B") },
	Despertar = { Color3.fromHex("FFE066"), Color3.fromHex("FF9D00") },
	Giros = Color3.fromHex("FFD23F"),
	Fragmentos = Color3.fromHex("C77DFF"),
}

Tema.FonteCartoon = Font.new("rbxasset://fonts/families/FredokaOne.json")
Tema.FonteCorpo = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
Tema.FonteNumeros = Font.new("rbxasset://fonts/families/FredokaOne.json")

return Tema
