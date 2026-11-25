-- Equipamento (RPG): a aba Personagem mostra os cinco espaços (elmo, armadura, manoplas, botas e
-- arma) com a peça em 3D, o "olho" de ocultar o visual (os bônus continuam), os bônus somados
-- e os de conjunto. As outras abas listam as peças de cada tipo para equipar, aprimorar com
-- Fragmentos ou desmontar (dois toques). O servidor confere tudo; aqui só mostra e pede.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Equip = require(Shared.Dados.Equipamento)
local Visual = require(Shared.Dados.EquipamentoVisual)
local Formato = require(Shared.Formato)
local Cores = require(Shared.Tema).Orbita
local Cartoes = require(script.Parent.Parent.Cartoes)
local Estado = require(script.Parent.Parent.Estado)
local Kit = require(script.Parent.Parent.Kit)
local Navegacao = require(script.Parent.Parent.Navegacao)
local Malha = require(script.Parent.Parent.Parent.Mundo.Nexo3D.Malha)

local Tela = {}
Tela.ICONE = 24 -- emblema do guardião

local ICONE_ESPACO = { elmo = 33, armadura = 24, manoplas = 10, botas = 30, arma = 26 }
local PECA_VITRINE = {
	elmo = "elmo",
	armadura = "armadura",
	manoplas = "manopla_d",
	botas = "bota_d",
	arma = "arma",
}

local estrutura: Cartoes.Estrutura
local abas: { [string]: Cartoes.Aba } = {}
local aba = "Personagem"
local aviso: (string) -> ()
local pedindo = false
local desmontando: string? = nil
local prontas: Malha.Cache = {}
type Vitrine = { modelo: Model, camera: Camera, raio: number, alvo: Vector3 }
local girando: { Vitrine } = {}

local function corRaridade(r: number): Color3
	return Color3.fromHex(Equip.RARIDADES[r].cor)
end

-- Peça em 3D girando dentro do cartão
local function vitrine(
	pai: Instance,
	conjunto: string,
	espaco: string,
	posicao: UDim2,
	tamanho: UDim2
)
	local v = Kit.novo("ViewportFrame", {
		BackgroundTransparency = 1,
		Ambient = Color3.fromHex("8C82B4"),
		LightColor = Color3.fromHex("FFF4E6"),
		LightDirection = Vector3.new(-0.6, -1, -0.8),
		Position = posicao,
		Size = tamanho,
		Parent = pai,
	}) :: ViewportFrame
	local modelo = Instance.new("Model")
	local camadas = ((Visual :: any)[conjunto] or {})[PECA_VITRINE[espaco]] or {}
	local minimo, maximo = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, m in camadas do
		local ok, parte, centro = pcall(Malha.criar, m.malha, prontas)
		if ok then
			parte.Material = (Enum.Material :: any)[m.material] or Enum.Material.SmoothPlastic
			parte.CFrame = CFrame.new(centro)
			parte.Parent = modelo
			minimo = minimo:Min(centro - parte.Size / 2)
			maximo = maximo:Max(centro + parte.Size / 2)
		end
	end
	if #modelo:GetChildren() == 0 then
		return
	end
	modelo.Parent = v
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = v
	v.CurrentCamera = camera
	local raio = (maximo - minimo).Magnitude * 1.55 + 0.5
	table.insert(
		girando,
		{ modelo = modelo, camera = camera, raio = raio, alvo = (minimo + maximo) / 2 }
	)
end

local function colecao(): (Equip.Colecao, number)
	local estado = Estado.atual :: any
	local frag = if estado and type(estado.corredor) == "table"
		then estado.corredor.fragmentos or 0
		else 0
	return Equip.normalizar(estado and estado.equipamento), frag
end

local function pedir(acao: string, ...: any)
	if pedindo then
		return
	end
	pedindo = true
	local args = table.pack(...)
	task.spawn(function()
		local _, msg = Estado.pedir(acao, table.unpack(args, 1, args.n))
		pedindo = false
		if msg then
			aviso(msg)
		end
	end)
end

local function texto(pai: Instance, props: { [string]: any }): TextLabel
	props.Parent = pai
	return Kit.texto(props)
end

local function botao(
	pai: Instance,
	rotulo: string,
	tom: Kit.Tom,
	posicao: UDim2,
	tamanho: UDim2,
	acao: () -> ()
)
	local b = Kit.botaoPlaca({
		texto = rotulo,
		tamanho = tamanho,
		tamanhoTexto = 14,
		tom = tom,
		pai = pai,
		aoClicar = acao,
	})
	b.placa.quadro.Position = posicao
	return b
end

-- ===================================================================== aba Personagem

local function abaPersonagem()
	local c = colecao()
	local total = Equip.total(c)
	local partes = {}
	for _, nome in Equip.ATRIBUTOS do
		table.insert(
			partes,
			string.format("<b>+%d%%</b> %s", total[nome], Equip.NOMES_ATRIBUTOS[nome])
		)
	end
	Cartoes.banner({
		pai = estrutura.lista,
		ordem = 1,
		cor = Cores.Lilas,
		icone = Tela.ICONE,
		titulo = "Seu equipamento",
		texto = table.concat(partes, " · ")
			.. '<br/><font color="#C9C7D6">As peças caem das criaturas do Corredor dos Perdidos. O olho esconde o visual sem tirar os bônus.</font>',
		altura = 118,
	})
	Cartoes.secao(estrutura.lista, 2, "Equipado", "Toque em Trocar para ver as peças do espaço")
	local grade = Cartoes.grade(estrutura.lista, 3, Vector2.new(210, 330))
	for i, espaco in Equip.ESPACOS do
		local uid = c.equipados[espaco]
		local g = uid and c.lista[uid]
		local item = g and Equip.porId[g.item]
		local cor = if item then corRaridade(item.raridade) else Cores.Borda
		local p = Kit.placa({
			tamanho = UDim2.fromScale(1, 1),
			borda = cor,
			corte = 12,
			ordem = i,
			pai = grade,
		})
		texto(p.conteudo, {
			fonte = "titulo",
			Text = string.upper(Equip.NOMES_ESPACOS[espaco]),
			TextSize = 13,
			TextColor3 = Cores.TextoSuave,
			Position = UDim2.fromOffset(8, 6),
			Size = UDim2.new(1, -16, 0, 16),
		})
		if item and g then
			vitrine(
				p.conteudo,
				item.conjunto,
				espaco,
				UDim2.fromOffset(20, 24),
				UDim2.new(1, -40, 0, 120)
			)
			texto(p.conteudo, {
				fonte = "titulo",
				Text = item.nome .. (if g.nivel > 0 then "  +" .. g.nivel else ""),
				TextSize = 17,
				TextColor3 = Kit.corLegivel(cor),
				TextWrapped = true,
				Position = UDim2.fromOffset(6, 146),
				Size = UDim2.new(1, -12, 0, 40),
			})
			texto(p.conteudo, {
				Text = Equip.texto(Equip.atributos(g)),
				TextSize = 13,
				TextColor3 = Cores.Menta,
				TextWrapped = true,
				Position = UDim2.fromOffset(6, 188),
				Size = UDim2.new(1, -12, 0, 34),
			})
			local oculto = c.ocultos[espaco] == true
			botao(
				p.conteudo,
				if oculto then "◌ Oculto" else "◉ Visível",
				if oculto then "neutro" else "menta",
				UDim2.new(0, 6, 1, -96),
				UDim2.new(1, -12, 0, 40),
				function()
					pedir("OcultarEquipamento", espaco, not oculto)
				end
			)
		else
			texto(p.conteudo, {
				Text = "Vazio",
				TextSize = 16,
				TextColor3 = Cores.TextoSuave,
				Position = UDim2.fromOffset(6, 80),
				Size = UDim2.new(1, -12, 0, 24),
			})
		end
		botao(
			p.conteudo,
			"Trocar",
			"lilas",
			UDim2.new(0, 6, 1, -50),
			UDim2.new(1, -12, 0, 40),
			function()
				aba = espaco
				estrutura.conteudo.CanvasPosition = Vector2.zero
				Tela.desenhar()
			end
		)
	end
	-- conjuntos com pelo menos uma peça equipada
	Cartoes.secao(estrutura.lista, 4, "Conjuntos", "3 e 5 peças do mesmo mundo dão bônus extra")
	local ordem = 5
	local contagem = Equip.pecasPorConjunto(c)
	for _, conjunto in Equip.CONJUNTOS do
		local n = contagem[conjunto.id]
		if not n then
			continue
		end
		local marca3 = if n >= 3 then "✓" else "·"
		local marca5 = if n >= 5 then "✓" else "·"
		Kit.texto({
			RichText = true,
			Text = string.format(
				'<font color="#%s"><b>%s %d/5</b></font>   %s 3 peças: %s   %s 5 peças: %s',
				conjunto.cor,
				conjunto.nome,
				n,
				marca3,
				Equip.texto(conjunto.bonus3),
				marca5,
				Equip.texto(conjunto.bonus5)
			),
			TextSize = 15,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = ordem,
			Parent = estrutura.lista,
		})
		ordem += 1
	end
end

-- ===================================================================== aba de um espaço

local function abaEspaco(espaco: string)
	local c, frag = colecao()
	local uids = {}
	for uid, g in c.lista do
		if Equip.porId[g.item].espaco == espaco then
			table.insert(uids, uid)
		end
	end
	table.sort(uids, function(a, b)
		local ea, eb = c.equipados[espaco] == a, c.equipados[espaco] == b
		if ea ~= eb then
			return ea
		end
		local ia, ib = Equip.porId[c.lista[a].item], Equip.porId[c.lista[b].item]
		if ia.raridade ~= ib.raridade then
			return ia.raridade > ib.raridade
		end
		if c.lista[a].nivel ~= c.lista[b].nivel then
			return c.lista[a].nivel > c.lista[b].nivel
		end
		return a < b
	end)
	Cartoes.secao(
		estrutura.lista,
		1,
		Equip.NOMES_ESPACOS[espaco],
		string.format("%d peças · ◆ %s Fragmentos", #uids, Formato.inteiro(frag))
	)
	if #uids == 0 then
		Kit.texto({
			Text = "Nenhuma peça deste tipo ainda. Derrote criaturas no Corredor dos Perdidos: os chefes deixam cair equipamento com frequência.",
			TextSize = 17,
			TextColor3 = Cores.TextoSuave,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 2,
			Parent = estrutura.lista,
		})
		return
	end
	local grade = Cartoes.grade(estrutura.lista, 2, Vector2.new(210, 360))
	for i, uid in uids do
		local g = c.lista[uid]
		local item = Equip.porId[g.item]
		local cor = corRaridade(item.raridade)
		local equipado = c.equipados[espaco] == uid
		local p = Kit.placa({
			tamanho = UDim2.fromScale(1, 1),
			borda = if equipado then Cores.Menta else cor,
			corte = 12,
			ordem = i,
			pai = grade,
		})
		vitrine(
			p.conteudo,
			item.conjunto,
			espaco,
			UDim2.fromOffset(20, 6),
			UDim2.new(1, -40, 0, 120)
		)
		texto(p.conteudo, {
			fonte = "titulo",
			Text = item.nome .. (if g.nivel > 0 then "  +" .. g.nivel else ""),
			TextSize = 17,
			TextColor3 = Kit.corLegivel(cor),
			TextWrapped = true,
			Position = UDim2.fromOffset(6, 128),
			Size = UDim2.new(1, -12, 0, 40),
		})
		texto(p.conteudo, {
			Text = Equip.RARIDADES[item.raridade].nome
				.. " · Conjunto "
				.. Equip.porConjunto[item.conjunto].nome,
			TextSize = 12,
			TextColor3 = Cores.TextoSuave,
			Position = UDim2.fromOffset(6, 168),
			Size = UDim2.new(1, -12, 0, 16),
		})
		texto(p.conteudo, {
			Text = Equip.texto(Equip.atributos(g)),
			TextSize = 13,
			TextColor3 = Cores.Menta,
			TextWrapped = true,
			Position = UDim2.fromOffset(6, 186),
			Size = UDim2.new(1, -12, 0, 34),
		})
		botao(
			p.conteudo,
			if equipado then "Desequipar" else "Equipar",
			if equipado then "menta" else "lilas",
			UDim2.new(0, 6, 1, -132),
			UDim2.new(1, -12, 0, 40),
			function()
				pedir("EquiparItem", uid, not equipado)
			end
		)
		local custo = Equip.custoAprimorar(g)
		botao(
			p.conteudo,
			if custo then string.format("Aprimorar ◆ %d", custo) else "Nível máximo",
			if custo and frag >= custo then "lilas" else "neutro",
			UDim2.new(0, 6, 1, -88),
			UDim2.new(1, -12, 0, 38),
			function()
				if custo then
					pedir("AprimorarItem", uid)
				end
			end
		)
		local confirmar = desmontando == uid
		botao(
			p.conteudo,
			if confirmar
				then string.format("Confirmar (+%d)", Equip.valorDesmontar(g))
				else "Desmontar",
			"neutro",
			UDim2.new(0, 6, 1, -44),
			UDim2.new(1, -12, 0, 36),
			function()
				if equipado then
					aviso("Desequipe a peça antes de desmontar.")
					return
				end
				if desmontando ~= uid then
					desmontando = uid
					Tela.desenhar()
					return
				end
				desmontando = nil
				pedir("DesmontarItem", uid)
			end
		)
	end
end

function Tela.desenhar()
	if Navegacao.aberto() ~= "Equipamento" or not Estado.atual then
		return
	end
	for nome, a in abas do
		a.definirAtiva(nome == aba)
	end
	table.clear(girando)
	for _, filho in estrutura.lista:GetChildren() do
		if filho:IsA("GuiObject") then
			filho:Destroy()
		end
	end
	local ok, erro = pcall(if aba == "Personagem"
		then abaPersonagem
		else function()
			abaEspaco(aba)
		end)
	if not ok then
		warn("[Equipamento] " .. tostring(erro))
	end
end

function Tela.abrir()
	Navegacao.alternar("Equipamento")
end

function Tela.montar(aoAviso: (string) -> ())
	aviso = aoAviso
	local painel = Navegacao.criarPainel(
		"Equipamento",
		{ titulo = "Equipamento", icone = Tela.ICONE },
		function()
			desmontando = nil
			Tela.desenhar()
		end
	)
	estrutura = Cartoes.estrutura(painel.conteudo)
	local lista = { { "Personagem", "Personagem", 9, Cores.Lilas } }
	for _, espaco in Equip.ESPACOS do
		table.insert(
			lista,
			{ espaco, Equip.NOMES_ESPACOS[espaco], ICONE_ESPACO[espaco], Color3.fromHex("FFC83D") }
		)
	end
	for i, d in lista do
		abas[d[1]] = Cartoes.aba(estrutura.lateral, i, d[2], d[3], d[4], function()
			aba = d[1]
			desmontando = nil
			estrutura.conteudo.CanvasPosition = Vector2.zero
			Tela.desenhar()
		end)
	end
	Estado.aoMudar(function()
		Tela.desenhar()
	end)
	RunService.RenderStepped:Connect(function()
		if #girando == 0 then
			return
		end
		local t = os.clock()
		for i, g in girando do
			local a = t * 0.7 + i
			g.camera.CFrame = CFrame.lookAt(
				g.alvo + Vector3.new(math.sin(a) * g.raio, g.raio * 0.3, math.cos(a) * g.raio),
				g.alvo
			)
		end
	end)
end

return Tela
