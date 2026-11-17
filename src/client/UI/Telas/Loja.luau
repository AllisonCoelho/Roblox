-- Loja do Nexo: Passe de Temporada (níveis, XP e resgates), pacotes pagos e cosméticos.
-- Compra e resgate são pedidos ao servidor; aqui só mostramos o estado.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Auras = require(Shared.Dados.Auras)
local Conveniencia = require(Shared.Dados.Conveniencia)
local Cosmeticos = require(Shared.Dados.Cosmeticos)
local Monetizacao = require(Shared.Dados.Monetizacao)
local Temporada = require(Shared.Dados.Temporada)
local Cores = require(Shared.Tema).Orbita
local Estado = require(script.Parent.Parent.Estado)
local Kit = require(script.Parent.Parent.Kit)
local Navegacao = require(script.Parent.Parent.Navegacao)

local Loja = {}

type Opcoes = {
	aviso: (string) -> (),
	oferecer: (string) -> (),
	oferecerItem: (any) -> (),
	temPasse: (string) -> boolean,
}

local ABAS = { "Temporada", "Pacotes", "Itens", "Cosméticos", "Extras" }
local NOMES_TIPO = {
	titulo = "Títulos",
	distintivo = "Distintivos",
	rastro = "Rastros",
	ritual = "Estilos de Ritual",
	aparencia = "Aparências de Aura",
	emote = "Emotes de Vitória",
	finalizacao = "Finalizações",
}
local PACOTES = { "iniciante", "vip", "fundador", "ritualPersonalizado", "passeTemporada" }
local GRUPOS = { "titulos", "trilhas", "aparenciaAlternativa", "emotesVitoria", "finalizacoes" }
local NOMES_LIMIAR = {
	[0] = "Nunca",
	[1000] = "1 em 1 mil",
	[10000] = "1 em 10 mil",
	[100000] = "1 em 100 mil",
	[1000000] = "1 em 1 milhão",
	[10000000] = "1 em 10 milhões",
}

local op: Opcoes
local aba = "Temporada"
local lista: Frame
local botoesAba: { Kit.BotaoPlaca } = {}
local posicao = 0
local ocupado = false

local function proxima(): number
	posicao += 1
	return posicao
end

local function linha(texto: string, cor: Color3?, tamanho: number?)
	return Kit.texto({
		Text = texto,
		TextColor3 = cor or Cores.Texto,
		TextSize = tamanho or 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		RichText = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -12, 0, 0),
		LayoutOrder = proxima(),
		Parent = lista,
	})
end

local function botao(texto: string, tom: any, aoClicar: () -> ()): Kit.BotaoPlaca
	return Kit.botaoPlaca({
		texto = texto,
		tamanho = UDim2.new(1, -12, 0, 50),
		tamanhoTexto = 16,
		tom = tom,
		pai = lista,
		ordem = proxima(),
		aoClicar = aoClicar,
	})
end

local function pedir(acao: string, ...: any)
	if ocupado then
		return
	end
	ocupado = true
	local args = table.pack(...)
	task.spawn(function()
		local _, msg = Estado.pedir(acao, table.unpack(args, 1, args.n))
		ocupado = false
		if msg then
			op.aviso(msg)
		end
	end)
end

local function nomeItem(id: string): string
	local item = Cosmeticos.porId[id]
	return if item
		then string.format(
			'<font color="#%s">%s</font> · %s',
			item.cor,
			item.nome,
			NOMES_TIPO[item.tipo]
		)
		else id
end

local function barraXP(fracao: number)
	local fundo: Frame = Kit.novo("Frame", {
		BackgroundColor3 = Cores.Elevado,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -12, 0, 14),
		LayoutOrder = proxima(),
		Parent = lista,
	})
	Kit.novo("Frame", {
		BackgroundColor3 = Cores.Lilas,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(math.clamp(fracao, 0, 1), 1),
		Parent = fundo,
	})
end

local function mostrarTemporada(estado: any)
	local t = Temporada.de(estado.temporada and table.clone(estado.temporada) or nil)
	local premium = op.temPasse("passeTemporada")
	local agora = Estado.agora()
	local nivel = Temporada.nivel(t.xp)
	linha(Temporada.NOME, Cores.Lilas, 22)
	if Temporada.ativa(agora) then
		local dias = math.max(0, math.ceil((Temporada.FIM - agora) / 86400))
		linha(
			string.format("Termina em %d dia%s", dias, if dias == 1 then "" else "s"),
			Cores.TextoSuave
		)
	elseif agora < Temporada.INICIO then
		linha("Começa em breve.", Cores.TextoSuave)
	else
		linha("Temporada encerrada — resgate o que já alcançou.", Cores.TextoSuave)
	end
	local maximo = nivel >= Temporada.NIVEIS
	local resto = t.xp - nivel * Temporada.XP_POR_NIVEL
	linha(
		if maximo
			then string.format("Nível %d / %d  ·  completo!", nivel, Temporada.NIVEIS)
			else string.format(
				"Nível %d / %d  ·  %d / %d XP",
				nivel,
				Temporada.NIVEIS,
				math.floor(resto),
				Temporada.XP_POR_NIVEL
			),
		Cores.Texto,
		20
	)
	barraXP(if maximo then 1 else resto / Temporada.XP_POR_NIVEL)
	linha(
		string.format(
			"XP: giro +%d (até %d por dia) · andar de Incursão +%d · vitória +%d%s",
			Temporada.XP.giro,
			Temporada.TETO_GIRO_DIA,
			Temporada.XP.andar,
			Temporada.XP.vitoria,
			if op.temPasse("vip") then " · VIP +10%" else ""
		),
		Cores.TextoSuave,
		15
	)
	if not premium then
		local produto = Monetizacao.porId.passeTemporada
		botao(
			string.format("Liberar trilha premium · %d Robux", produto.preco),
			"lilas",
			function()
				op.oferecer("passeTemporada")
			end
		)
	end
	for n = 1, Temporada.NIVEIS do
		local r = Temporada.RECOMPENSAS[n]
		if r then
			for _, trilha in { "gratis", "premium" } do
				local id = (r :: any)[trilha]
				if id then
					local resgatado = t.resgates[trilha][tostring(n)] == true
					local bloqueado = trilha == "premium" and not premium
					local alcancado = nivel >= n
					local estadoTexto = if resgatado
						then "✓ resgatado"
						elseif bloqueado then "🔒 premium"
						elseif alcancado then "Resgatar"
						else "nível " .. n
					local b = botao(
						string.format(
							"Nv %d · %s · %s  —  %s",
							n,
							if trilha == "premium" then "Premium" else "Grátis",
							nomeItem(id),
							estadoTexto
						),
						if resgatado
							then "menta"
							elseif alcancado and not bloqueado then "lilas"
							else "neutro",
						function()
							if bloqueado then
								op.oferecer("passeTemporada")
							elseif not resgatado and alcancado then
								pedir("ResgatarTemporada", n, trilha)
							end
						end
					)
					b.rotulo.RichText = true
				end
			end
		end
	end
end

local function mostrarPacotes()
	linha("Só aparência: nada aqui muda chance de aura nem poder.", Cores.TextoSuave, 15)
	for _, id in PACOTES do
		local produto = Monetizacao.porId[id]
		local tem = op.temPasse(id)
		linha(
			string.format("<b>%s</b>  ·  %d Robux", produto.nome, produto.preco),
			Cores.Lilas,
			20
		)
		linha(produto.beneficio, Cores.TextoSuave, 16)
		local itens = Cosmeticos.PACOTES[id]
		if itens then
			local nomes = {}
			for _, item in itens do
				table.insert(nomes, nomeItem(item))
			end
			linha("Inclui: " .. table.concat(nomes, "  ·  "), Cores.Texto, 15)
		end
		if id == "vip" then
			linha("Também: nome dourado no chat e +10% de XP da Temporada.", Cores.Texto, 15)
		end
		botao(if tem then "Possui ✓" else "Comprar", if tem then "menta" else "lilas", function()
			if not tem then
				op.oferecer(id)
			end
		end)
	end
end

local function mostrarCosmeticos(estado: any)
	local c = estado.cosmeticos or Cosmeticos.padrao()
	local possui = c.possui or {}
	local equipados = c.equipados or {}
	local algum = false
	for _, tipo in Cosmeticos.TIPOS do
		local itens = {}
		for _, item in Cosmeticos.ITENS do
			if item.tipo == tipo and possui[item.id] then
				table.insert(itens, item)
			end
		end
		if #itens > 0 then
			algum = true
			linha(NOMES_TIPO[tipo], Cores.Lilas, 20)
			for _, item in itens do
				local usando = equipados[tipo] == item.id
				local b = botao(
					string.format(
						'<font color="#%s">%s</font>%s  —  %s',
						item.cor,
						if tipo == "distintivo" then item.texto .. "  " .. item.nome else item.nome,
						if tipo == "rastro" then "  ·  " .. item.texto else "",
						if usando then "Equipado ✓" else "Equipar"
					),
					if usando then "menta" else "neutro",
					function()
						pedir("EquiparCosmetico", tipo, if usando then "" else item.id)
					end
				)
				b.rotulo.RichText = true
			end
		end
	end
	if not algum then
		linha(
			"Você ainda não tem cosméticos. Suba níveis na Temporada (trilha grátis) ou veja os Pacotes.",
			Cores.TextoSuave
		)
	end
end

local function mostrarItens(estado: any)
	local possui = estado.cosmeticos and estado.cosmeticos.possui or {}
	linha(
		"Itens avulsos: compre uma vez, são seus para sempre. Só aparência.",
		Cores.TextoSuave,
		15
	)
	for _, grupo in GRUPOS do
		local produto = Monetizacao.porId[grupo]
		linha(
			string.format("<b>%s</b>  ·  %s Robux", produto.nome, produto.precoTexto),
			Cores.Lilas,
			20
		)
		linha(produto.beneficio, Cores.TextoSuave, 15)
		for _, item in Cosmeticos.doGrupo(grupo) do
			local tem = possui[item.id] == true
			local b = botao(
				string.format(
					'<font color="#%s">%s</font>  ·  %s  —  %s',
					item.cor,
					item.nome,
					item.texto,
					if tem then "Possui ✓" else (item.preco :: number) .. " Robux"
				),
				if tem then "menta" else "neutro",
				function()
					if not tem then
						op.oferecerItem(item)
					end
				end
			)
			b.rotulo.RichText = true
		end
	end
end

local function mostrarExtras(estado: any)
	-- Auto Inteligente
	local temAuto = op.temPasse("autoInteligente")
	local auto = estado.auto or Conveniencia.autoPadrao()
	linha("<b>Auto Inteligente</b>  ·  79 Robux", Cores.Lilas, 20)
	linha(Monetizacao.porId.autoInteligente.beneficio, Cores.TextoSuave, 15)
	if temAuto then
		local indice = table.find(Conveniencia.LIMIARES, auto.pararChance) or 1
		botao(
			"Parar em aura de raridade: " .. NOMES_LIMIAR[auto.pararChance or 0],
			"neutro",
			function()
				local proximo = Conveniencia.LIMIARES[indice % #Conveniencia.LIMIARES + 1]
				pedir("ConfigurarAuto", proximo, auto.pararNova == true)
			end
		)
		botao(
			"Parar em aura nova: " .. (if auto.pararNova then "Sim" else "Não"),
			if auto.pararNova then "menta" else "neutro",
			function()
				pedir("ConfigurarAuto", auto.pararChance or 0, not auto.pararNova)
			end
		)
	else
		botao("Comprar · 79 Robux", "lilas", function()
			op.oferecer("autoInteligente")
		end)
	end

	-- Presets de Auras
	local temPresets = op.temPasse("presets")
	linha("<b>Presets de Auras</b>  ·  49 Robux", Cores.Lilas, 20)
	linha(Monetizacao.porId.presets.beneficio, Cores.TextoSuave, 15)
	if temPresets then
		local presets = estado.presets or {}
		for slot = 1, Conveniencia.MAX_PRESETS do
			local p = presets[slot]
			local aura = p and p.aura ~= "" and Auras.porId[p.aura]
			local resumo = if p then (if aura then aura.nome else "sem aura") else "vazio"
			linha(string.format("Preset %d  ·  %s", slot, resumo), Cores.Texto, 16)
			botao("Salvar o visual atual no preset " .. slot, "neutro", function()
				pedir("SalvarPreset", slot)
			end)
			if p then
				botao("Usar preset " .. slot, "lilas", function()
					pedir("AplicarPreset", slot)
				end)
			end
		end
	else
		botao("Comprar · 49 Robux", "lilas", function()
			op.oferecer("presets")
		end)
	end

	-- Assinatura do Nexo
	local assinante = op.temPasse("assinatura")
	linha("<b>Assinatura do Nexo</b>  ·  99 Robux/mês", Cores.Lilas, 20)
	linha(Monetizacao.porId.assinatura.beneficio, Cores.TextoSuave, 15)
	botao(
		if assinante then "Assinante ✓" else "Assinar",
		if assinante then "menta" else "lilas",
		function()
			if not assinante then
				op.oferecer("assinatura")
			end
		end
	)

	-- Servidor Privado
	linha("<b>Servidor Privado</b>  ·  49 Robux/mês", Cores.Lilas, 20)
	linha(
		"Na página do jogo no Roblox, abra a aba Servidores → Criar servidor privado. Chame amigos pelo link. O dono aparece com 🏠 no chat.",
		Cores.TextoSuave,
		15
	)
	local dono = workspace:GetAttribute("ServidorPrivadoDono")
	if type(dono) == "number" then
		linha(
			if dono == Players.LocalPlayer.UserId
				then "Você está no seu servidor privado."
				else "Você está em um servidor privado.",
			Cores.Menta,
			16
		)
	end
end

local function atualizar()
	if Navegacao.aberto() ~= "Loja" then
		return
	end
	posicao = 0
	for _, filho in lista:GetChildren() do
		if filho:IsA("GuiObject") then
			filho:Destroy()
		end
	end
	for i, b in botoesAba do
		b.definirTom(if ABAS[i] == aba then "lilas" else "neutro")
	end
	local estado = Estado.atual
	if not estado then
		linha("Carregando...", Cores.TextoSuave)
		return
	end
	if aba == "Temporada" then
		mostrarTemporada(estado)
	elseif aba == "Pacotes" then
		mostrarPacotes()
	elseif aba == "Itens" then
		mostrarItens(estado)
	elseif aba == "Extras" then
		mostrarExtras(estado)
	else
		mostrarCosmeticos(estado)
	end
end

function Loja.abrir()
	Navegacao.alternar("Loja")
end

-- Abre a Loja já na aba pedida (ex.: o cartão do jogador abre o Passe de Temporada)
function Loja.abrirAba(nome: string)
	if table.find(ABAS, nome) then
		aba = nome
	end
	if Navegacao.aberto() == "Loja" then
		atualizar()
	else
		Navegacao.abrir("Loja")
	end
end

function Loja.montar(opcoes: Opcoes)
	op = opcoes
	local painel =
		Navegacao.criarPainel("Loja", { titulo = "Loja do Nexo", icone = "✦" }, atualizar)
	local barra: Frame = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 0, 46),
		Parent = painel.conteudo,
	})
	Kit.novo("UIGridLayout", {
		CellSize = UDim2.new(1 / #ABAS, -4, 0, 42),
		CellPadding = UDim2.fromOffset(6, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = barra,
	})
	for i, nome in ABAS do
		local b = Kit.botaoPlaca({
			texto = nome,
			tamanho = UDim2.new(),
			tamanhoTexto = 16,
			pai = barra,
			aoClicar = function()
				aba = nome
				atualizar()
			end,
		})
		b.placa.quadro.LayoutOrder = i
		botoesAba[i] = b
	end
	local rolagem = Kit.rolagem(painel.conteudo)
	rolagem.Position = UDim2.fromOffset(12, 58)
	rolagem.Size = UDim2.new(1, -24, 1, -62)
	lista = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = rolagem,
	})
	Kit.novo(
		"UIListLayout",
		{ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = lista }
	)
	Estado.aoMudar(function()
		atualizar()
	end)
	Players.LocalPlayer.AttributeChanged:Connect(function(nome)
		if string.sub(nome, 1, 6) == "Passe_" then
			atualizar()
		end
	end)
end

return Loja
