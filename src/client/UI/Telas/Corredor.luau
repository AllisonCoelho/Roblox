-- Corredor dos Perdidos: as seis fases em cartões, com o que cada uma pede (Pontuação e a fase
-- anterior), o que dá (Fragmentos) e o botão de ir. Abre nos Portais Fragmentados. Quem decide
-- se entra é o servidor ("CorredorIr"); aqui só mostra e pede.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Corredor = require(Shared.Dados.Corredor)
local Formato = require(Shared.Formato)
local Cores = require(Shared.Tema).Orbita
local Cartoes = require(script.Parent.Parent.Cartoes)
local Estado = require(script.Parent.Parent.Estado)
local Kit = require(script.Parent.Parent.Kit)
local Navegacao = require(script.Parent.Parent.Navegacao)

local Tela = {}

Tela.ICONE = 9 -- órbita (portais)
-- um ícone do atlas por mundo (lasca, árvore de cristal, chama, gota, coroa, olho)
local ICONES = { 8, 31, 20, 21, 33, 34 }

local jogador = Players.LocalPlayer
local lista: Frame
local aviso: (string) -> ()
local pedindo = false

local function desenhar()
	local estado = Estado.atual
	if not estado or Navegacao.aberto() ~= "Corredor" then
		return
	end
	for _, filho in lista:GetChildren() do
		if filho:IsA("GuiObject") then
			filho:Destroy()
		end
	end
	local p = Corredor.normalizar((estado :: any).corredor)
	local pontuacao = tonumber(jogador:GetAttribute("Pontuacao")) or 0
	local dentro = jogador:GetAttribute("CorredorFase")
	local restante = math.max(0, p.bonusAte - Estado.agora())
	local concluidas = 0
	for i = 1, Corredor.TOTAL do
		if Corredor.concluiu(p, i) then
			concluidas += 1
		end
	end
	Cartoes.banner({
		pai = lista,
		ordem = 1,
		cor = Cores.Lilas,
		icone = Tela.ICONE,
		titulo = string.format("Corredor dos Perdidos · %d / %d", concluidas, Corredor.TOTAL),
		texto = string.format(
			"Sua Pontuação de Aura <b>%s</b> · Fragmentos <b>%s</b><br/>"
				.. "Atravesse cada mundo até o Portão. Concluir dá Fragmentos e <b>Pontos de Aura em dobro por %d min</b>.<br/>"
				.. '<font color="#C9C7D6">%s</font>',
			Formato.inteiro(pontuacao),
			Formato.inteiro(p.fragmentos),
			math.floor(Corredor.BONUS_DURACAO / 60),
			if restante > 0
				then string.format(
					"Ressonância de Combate ativa: %s restantes",
					Formato.tempo(restante)
				)
				else "As criaturas dos mundos chegam em breve."
		),
		botao = if dentro then "Voltar ao Nexo" else nil,
		corBotao = Cores.Elevado,
		aoClicar = if dentro
			then function()
				task.spawn(function()
					local ok, msg = Estado.pedir("CorredorSair")
					if not ok and msg then
						aviso(msg)
					end
					Navegacao.fechar()
				end)
			end
			else nil,
		altura = 132,
	})
	Cartoes.secao(
		lista,
		2,
		"Mundos fragmentados",
		"Cada um pede a Pontuação e o anterior concluído"
	)
	local grade = Cartoes.grade(lista, 3, Vector2.new(214, 300))
	for i, f in Corredor.FASES do
		local pode, motivo = Corredor.podeEntrar(p, i, pontuacao)
		local feita = Corredor.concluiu(p, i)
		local cor = Color3.fromHex(f.cor)
		Cartoes.cartao({
			pai = grade,
			ordem = i,
			cor = cor,
			icone = ICONES[i],
			titulo = f.nome,
			subtitulo = string.format("Fase %d · Pontuação %s", i, Formato.inteiro(f.requisito)),
			linhas = {
				f.descricao,
				if feita
					then string.format("+%d Fragmentos (a cada 5 min)", f.repetir)
					else string.format("+%d Fragmentos na 1ª vez", f.primeira),
			},
			etiqueta = if feita
				then "CONCLUÍDA"
				elseif dentro == i then "VOCÊ ESTÁ AQUI"
				else nil,
			estado = if pode then "resgatar" else "travado",
			textoBotao = if pode then "Ir" else "Bloqueada",
			aoClicar = function()
				if not pode then
					aviso(motivo or "Fase bloqueada.")
					return
				end
				if pedindo then
					return
				end
				pedindo = true
				task.spawn(function()
					local ok, msg = Estado.pedir("CorredorIr", i)
					pedindo = false
					if ok then
						Navegacao.fechar()
					elseif msg then
						aviso(msg)
					end
				end)
			end,
		})
	end
end

function Tela.abrir()
	Navegacao.alternar("Corredor")
end

function Tela.montar(aoAviso: (string) -> ())
	aviso = aoAviso
	local painel = Navegacao.criarPainel(
		"Corredor",
		{ titulo = "Corredor dos Perdidos", icone = Tela.ICONE },
		desenhar
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
	Estado.aoMudar(desenhar)
	jogador:GetAttributeChangedSignal("Pontuacao"):Connect(desenhar)
	jogador:GetAttributeChangedSignal("CorredorFase"):Connect(desenhar)
end

return Tela
