-- Índice de auras no estilo das coleções dos jogos do Roblox: raridades na lateral (com quantas
-- você já tem), cartões com ícone, chance real e quantidade, e o botão de equipar.
-- As auras que faltam aparecem como "???" bloqueadas.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Auras = require(Shared.Dados.Auras)
local Formato = require(Shared.Formato)
local Icones = require(Shared.Dados.Icones)
local Perfil = require(Shared.Dados.Perfil)
local PontosAura = require(Shared.Dados.PontosAura)
local Cores = require(Shared.Tema).Orbita
local Cartoes = require(script.Parent.Parent.Cartoes)
local Estado = require(script.Parent.Parent.Estado)
local Kit = require(script.Parent.Parent.Kit)
local Navegacao = require(script.Parent.Parent.Navegacao)

local Indice = {}

local filtro = 0 -- 0 = todas; 1..7 = raridade
local estrutura: Cartoes.Estrutura
local abas: { [number]: Cartoes.Aba } = {}
local contagens: { [number]: TextLabel } = {}
local aviso: (string) -> ()
local contador: TextLabel
local progresso: Frame

local function equipar(aura: Auras.Aura)
	local estado = Estado.atual
	if not estado then
		aviso("Aguardando perfil")
		return
	end
	if not Perfil.possui(estado, aura.id) then
		aviso(
			string.format(
				"Desperte esta aura (1 em %s) para poder equipar.",
				Formato.chance(aura.chance)
			)
		)
		return
	end
	local alvo = if estado.equipada == aura.id then "" else aura.id
	task.spawn(function()
		local ok, msg = Estado.pedir("Equipar", alvo)
		if not ok and msg then
			aviso(msg)
		end
	end)
end

local function atualizar()
	local estado = Estado.atual
	if not estado then
		return
	end
	local descobertas = Auras.contarDescobertas(estado.auras)
	contador.Text = string.format("%d / %d", descobertas, #Auras.lista)
	progresso.Size = UDim2.fromScale(descobertas / #Auras.lista, 1)
	local porTier: { [number]: { tem: number, total: number } } = {}
	for _, aura in Auras.lista do
		local c = porTier[aura.tier] or { tem = 0, total = 0 }
		c.total += 1
		if Perfil.possui(estado, aura.id) then
			c.tem += 1
		end
		porTier[aura.tier] = c
	end
	for tier, rotulo in contagens do
		local c = if tier == 0 then { tem = descobertas, total = #Auras.lista } else porTier[tier]
		rotulo.Text = if c then string.format("%d/%d", c.tem, c.total) else "0/0"
	end
	for tier, a in abas do
		a.definirAtiva(tier == filtro)
	end
	if Navegacao.aberto() ~= "Indice" then
		return
	end

	local lista = estrutura.lista
	for _, filho in lista:GetChildren() do
		if filho:IsA("GuiObject") then
			filho:Destroy()
		end
	end
	local sorte = PontosAura.sorteTotal(estado)
	local nomeFiltro = if filtro == 0 then "Todas as auras" else Auras.Tiers[filtro].nome
	Cartoes.secao(lista, 1, nomeFiltro, "Toque numa aura sua para equipar")
	local grade = Cartoes.grade(lista, 2, Vector2.new(204, 236))
	for _, aura in Auras.lista do
		if filtro == 0 or aura.tier == filtro then
			local tier = Auras.Tiers[aura.tier]
			local tem = Perfil.possui(estado, aura.id)
			local equipada = tem and estado.equipada == aura.id
			Cartoes.cartao({
				pai = grade,
				ordem = aura.ordem,
				cor = Color3.fromHex(tier.cor),
				icone = if tem then Icones.aura(aura.estilo) else 32,
				titulo = if tem then aura.nome else "???",
				subtitulo = string.format(
					"%s · 1 em %s",
					tier.nome,
					Formato.chanceCurta(Auras.chanceEfetiva(aura, sorte))
				),
				etiqueta = if tem then "×" .. Formato.curto(estado.auras[aura.id]) else nil,
				estado = if not tem then "travado" elseif equipada then "equipado" else "equipar",
				textoBotao = if not tem then "A descobrir" elseif equipada then "Equipada" else nil,
				aoClicar = function()
					equipar(aura)
				end,
			})
		end
	end
end

function Indice.montar(aoAviso: (string) -> ())
	aviso = aoAviso
	local painel = Navegacao.criarPainel(
		"Indice",
		{ titulo = "Índice de Auras", icone = Icones.MENU.Indice, reserva = 110 },
		atualizar
	)
	contador = Kit.texto({
		Name = "Descobertas",
		fonte = "mono",
		Text = "0 / " .. #Auras.lista,
		TextSize = 16,
		TextColor3 = Cores.Lilas,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -88, 0.5, -1),
		Size = UDim2.fromOffset(104, 26),
		Parent = painel.cabecalho,
	})
	local trilho = Kit.novo("Frame", {
		BackgroundColor3 = Cores.Borda,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -88, 0.5, 16),
		Size = UDim2.fromOffset(90, 3),
		Parent = painel.cabecalho,
	})
	progresso = Kit.novo("Frame", {
		BackgroundColor3 = Cores.Lilas,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = trilho,
	})

	estrutura = Cartoes.estrutura(painel.conteudo)
	-- lateral rolável: 8 abas (todas + 7 raridades) não cabem em telas baixas
	estrutura.lateral.ClipsDescendants = true
	local function criarAba(tier: number, nome: string, cor: Color3, icone: number)
		local a = Cartoes.aba(estrutura.lateral, tier + 1, nome, icone, cor, function()
			filtro = tier
			estrutura.conteudo.CanvasPosition = Vector2.zero
			atualizar()
		end)
		a.placa.quadro.Size = UDim2.new(1, 0, 0, 48)
		contagens[tier] = Kit.texto({
			fonte = "mono",
			TextSize = 13,
			TextColor3 = Cores.TextoSuave,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(1, -52, 0, 0),
			Size = UDim2.new(0, 44, 1, 0),
			Parent = a.placa.conteudo,
		})
		abas[tier] = a
	end
	criarAba(0, "Todas", Cores.Lilas, Icones.MENU.Indice)
	for i, tier in Auras.Tiers do
		criarAba(i, tier.nome, Color3.fromHex(tier.cor), Icones.AURAS.brilho)
	end
	Estado.aoMudar(function()
		atualizar()
	end)
end

function Indice.abrir()
	Navegacao.alternar("Indice")
end

return Indice
