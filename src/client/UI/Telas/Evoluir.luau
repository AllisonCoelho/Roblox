-- Evoluir: onde os Pontos de Aura viram força. No topo, o saldo, o ganho por segundo, a
-- Pontuação de Aura e a sorte do giro; embaixo, um cartão por evolução (Nível, Fluxo, Sorte).
-- O saldo anda sozinho (atributos do Player escritos pelo servidor a cada segundo).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Formato = require(Shared.Formato)
local PontosAura = require(Shared.Dados.PontosAura)
local Transcendencia = require(Shared.Dados.Transcendencia)
local Cores = require(Shared.Tema).Orbita
local Cartoes = require(script.Parent.Parent.Cartoes)
local Estado = require(script.Parent.Parent.Estado)
local Kit = require(script.Parent.Parent.Kit)
local Navegacao = require(script.Parent.Parent.Navegacao)

local Evoluir = {}

Evoluir.ICONE = 31 -- brilhos do atlas
local VISUAL = {
	nivel = { icone = 33, cor = Color3.fromHex("FFC83D") },
	fluxo = { icone = 30, cor = Color3.fromHex("7FD8FF") },
	sorte = { icone = 7, cor = Color3.fromHex("7BF0A0") },
}

local jogador = Players.LocalPlayer
local lista: Frame
local aviso: (string) -> ()
local comprando = false
-- assinatura do que está desenhado: só redesenha quando muda o que dá para comprar
local desenhado = ""

local function pontosAgora(): number
	return tonumber(jogador:GetAttribute("PontosAura")) or 0
end

local function numero(n: number): string
	return if n < 1000000 then Formato.inteiro(math.floor(n)) else Formato.curto(n)
end

local function decimal(n: number): string
	return (string.format("%.1f", n):gsub("%.", ","))
end

local function desenhar(forcar: boolean?)
	local estado = Estado.atual
	if not estado or Navegacao.aberto() ~= "Evoluir" then
		return
	end
	local p = PontosAura.normalizar(estado.poder)
	local saldo = pontosAgora()
	local partes = { tostring(p.nivel), tostring(p.fluxo), tostring(p.sorte) }
	for _, e in PontosAura.EVOLUCOES do
		local c = PontosAura.custo(e.id, (p :: any)[e.id])
		table.insert(partes, if c and saldo >= c then "1" else "0")
	end
	local assinatura = table.concat(partes, ",")
	if assinatura == desenhado and not forcar then
		return
	end
	desenhado = assinatura
	for _, filho in lista:GetChildren() do
		if filho:IsA("GuiObject") then
			filho:Destroy()
		end
	end

	local ganho = tonumber(jogador:GetAttribute("GanhoAura")) or 0
	local pontuacao = tonumber(jogador:GetAttribute("Pontuacao")) or 0
	local sorte = tonumber(jogador:GetAttribute("SorteTotal")) or PontosAura.sorteTotal(estado)
	Cartoes.banner({
		pai = lista,
		ordem = 1,
		cor = Cores.Lilas,
		icone = Evoluir.ICONE,
		titulo = string.format("%s Pontos de Aura", numero(saldo)),
		texto = string.format(
			'<font color="#B7FFD9"><b>+%s por segundo</b></font> com a aura equipada<br/>'
				.. "Pontuação de Aura <b>%s</b> · Sorte do giro <b>%sx</b> (máx. %dx)<br/>"
				.. '<font color="#C9C7D6">Sorte = evolução %sx × Transcendência %sx</font>',
			decimal(ganho),
			numero(pontuacao),
			decimal(sorte),
			PontosAura.SORTE_MAXIMA,
			decimal(PontosAura.sorteEvolucao(p)),
			decimal(Transcendencia.sorte(estado.transcendencia.nivel))
		),
		altura = 132,
	})
	Cartoes.secao(lista, 2, "Evoluções", "Pontos de Aura viram força, fluxo e sorte")
	local grade = Cartoes.grade(lista, 3, Vector2.new(220, 250))
	for i, e in PontosAura.EVOLUCOES do
		local atual = (p :: any)[e.id] :: number
		local custo = PontosAura.custo(e.id, atual)
		local efeito: string
		local proximo: string
		if e.id == "nivel" then
			efeito =
				string.format("Pontuação x%s", decimal(1 + PontosAura.NIVEL_POR_NIVEL * atual))
			proximo =
				string.format("→ x%s", decimal(1 + PontosAura.NIVEL_POR_NIVEL * (atual + 1)))
		elseif e.id == "fluxo" then
			efeito = string.format("Ganho x%s", decimal(1 + PontosAura.FLUXO_POR_NIVEL * atual))
			proximo =
				string.format("→ x%s", decimal(1 + PontosAura.FLUXO_POR_NIVEL * (atual + 1)))
		else
			efeito = string.format("Sorte %sx", decimal(1 + PontosAura.SORTE_POR_NIVEL * atual))
			proximo =
				string.format("→ %sx", decimal(1 + PontosAura.SORTE_POR_NIVEL * (atual + 1)))
		end
		local pode = custo ~= nil and saldo >= custo
		local visual = VISUAL[e.id]
		Cartoes.cartao({
			pai = grade,
			ordem = i,
			cor = visual.cor,
			icone = visual.icone,
			titulo = e.nome,
			subtitulo = string.format("Nv %d / %d", atual, e.maximo),
			linhas = { e.descricao, efeito .. "  " .. (if custo then proximo else "(máximo)") },
			estado = if custo == nil then "possui" elseif pode then "resgatar" else "travado",
			textoBotao = if custo == nil then "Máximo" else "✦ " .. numero(custo),
			aoClicar = function()
				if comprando or custo == nil then
					return
				end
				if not pode then
					aviso(string.format("Faltam %s Pontos de Aura.", numero(custo - pontosAgora())))
					return
				end
				comprando = true
				task.spawn(function()
					local ok, msg = Estado.pedir("Evoluir", e.id)
					comprando = false
					if not ok and msg then
						aviso(msg)
					end
					desenhar(true)
				end)
			end,
		})
	end
	Kit.texto({
		Text = "As auras mais raras continuam quase impossíveis sem evoluir: a sorte deixa tudo mais fácil, mas tem teto.",
		TextSize = 15,
		TextColor3 = Cores.TextoSuave,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 4,
		Parent = lista,
	})
end

function Evoluir.abrir()
	Navegacao.alternar("Evoluir")
end

function Evoluir.montar(aoAviso: (string) -> ())
	aviso = aoAviso
	local painel = Navegacao.criarPainel(
		"Evoluir",
		{ titulo = "Evoluir Aura", icone = Evoluir.ICONE },
		function()
			desenhar(true)
		end
	)
	local rolagem = Kit.rolagem(painel.conteudo)
	rolagem.Position = UDim2.fromOffset(12, 4)
	rolagem.Size = UDim2.new(1, -24, 1, -10)
	lista = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -8, 0, 0),
		Parent = rolagem,
	})
	Kit.novo("UIListLayout", {
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = lista,
	})
	-- o saldo muda todo segundo: redesenha só quando muda o que dá para comprar,
	-- mas o título do banner (saldo) acompanha sempre
	jogador:GetAttributeChangedSignal("PontosAura"):Connect(function()
		desenhar(false)
		local banner = lista:FindFirstChildWhichIsA("GuiObject")
		if banner then
			for _, d in banner:GetDescendants() do
				if d:IsA("TextLabel") and d.Text:find("Pontos de Aura") and not d.RichText then
					d.Text = string.format("%s Pontos de Aura", numero(pontosAgora()))
				end
			end
		end
	end)
	Estado.aoMudar(function()
		desenhar(true)
	end)
end

return Evoluir
