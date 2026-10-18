-- Presente diário em sequência de 7 dias (ver docs/design/09-popups.png)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Tema = require(Shared.Tema)
local PresentesDados = require(Shared.Dados.Presentes)
local Formato = require(Shared.Formato)
local UI = script.Parent.Parent
local C = require(UI.Componentes)
local Estado = require(UI.Estado)
local Navegacao = require(UI.Navegacao)
local Visual = require(UI.Visual)
local Avisos = require(UI.Popups.Avisos)

local Cores = Tema.Cores
local Presentes = {}

function Presentes.montar()
	local painel = Navegacao.criarPainel(
		"Presentes",
		{ titulo = "Presente do Dia", icone = "🎁", cor = "ouro" }
	)

	local grade = C.novo("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(4 * 210 + 3 * 20, 2 * 190 + 20),
		Position = UDim2.new(0.5, 0, 0, 30),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = painel.conteudo,
	})
	local subtitulo = C.textoEscuro({
		TextSize = 20,
		TextColor3 = Cores.TextoSuave,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 1, -150),
		Parent = painel.conteudo,
	})
	local botao = C.botao({
		cor = "verde",
		texto = "PEGAR",
		tamanho = UDim2.fromOffset(360, 70),
		tamanhoTexto = 32,
		posicao = UDim2.new(0.5, 0, 1, -104),
		ancora = Vector2.new(0.5, 0),
		pai = painel.conteudo,
		aoClicar = function()
			Avisos.resultado(Estado.pedir("PegarPresente"))
		end,
	})

	local function desenhar()
		for _, f in grade:GetChildren() do
			f:Destroy()
		end
		local estado = Estado.atual
		if not estado then
			return
		end
		local hoje = PresentesDados.diaAtual(Estado.agora())
		local p = estado.presente
		local disponivel = p.ultimoDia ~= hoje
		-- Qual dia da sequência é o "de hoje" e quantos já foram pegos neste ciclo
		local seqHoje
		if disponivel then
			seqHoje = if p.ultimoDia == hoje - 1 then p.sequencia + 1 else 1
		else
			seqHoje = p.sequencia
		end
		local total = #PresentesDados.Dias
		local indiceHoje = (seqHoje - 1) % total + 1
		for i, dia in PresentesDados.Dias do
			local pego = i < indiceHoje or (i == indiceHoje and not disponivel)
			local ehHoje = i == indiceHoje
			local ultimo = i == total
			local celula = C.cartaoClaro({
				Size = if ultimo then UDim2.fromOffset(440, 190) else UDim2.fromOffset(210, 190),
				Position = UDim2.fromOffset(((i - 1) % 4) * 230, math.floor((i - 1) / 4) * 210),
				Parent = grade,
			}, 20)
			if pego then
				celula.BackgroundColor3 = Color3.fromHex("D7F8E8")
			elseif ehHoje then
				C.degrade(celula, Color3.fromHex("FFF1C2"), Cores.OuroClaro)
				local s = celula:FindFirstChildOfClass("UIStroke") :: UIStroke
				s.Color = Cores.Rosa
				s.Thickness = 6
			elseif ultimo then
				C.degrade(celula, Color3.fromHex("FFF1C2"), Cores.Ouro)
			end
			if dia.docinho then
				Visual.docinho(dia.docinho, {
					tamanho = UDim2.fromOffset(110, 110),
					posicao = UDim2.new(0.5, 0, 0, 14),
					ancora = Vector2.new(0.5, 0),
					pai = celula,
				})
			else
				C.emoji(dia.icone, 64, {
					Position = UDim2.new(0.5, 0, 0, 22),
					AnchorPoint = Vector2.new(0.5, 0),
					Parent = celula,
				})
			end
			C.textoEscuro({
				Text = "Dia " .. i,
				Font = Tema.Fonte,
				TextSize = 22,
				Size = UDim2.new(1, 0, 0, 26),
				Position = UDim2.fromOffset(0, 124),
				Parent = celula,
			})
			C.textoEscuro({
				Text = dia.texto,
				TextSize = 16,
				TextColor3 = Cores.TextoSuave,
				Size = UDim2.new(1, 0, 0, 22),
				Position = UDim2.fromOffset(0, 152),
				Parent = celula,
			})
			if pego then
				C.texto({
					Text = "✓",
					TextSize = 34,
					TextColor3 = Cores.MentaEscuro,
					contorno = false,
					Size = UDim2.fromOffset(40, 40),
					Position = UDim2.new(1, -44, 0, 4),
					Parent = celula,
				})
			end
		end
		if disponivel then
			botao.definirCor("verde")
			botao.definirTexto("PEGAR")
			subtitulo.Text = if seqHoje == 1 and p.sequencia > 0
				then "A sequência recomeçou. Volte todo dia para chegar ao Dia 7!"
				else "Volte todo dia: o Dia 7 dá um Docinho Lendário!"
		else
			botao.definirCor("cinza")
			local faltam = 86400 - ((Estado.agora() - 3 * 3600) % 86400)
			botao.definirTexto("Volte em " .. Formato.tempo(faltam))
			subtitulo.Text = "Presente de hoje já foi pego!"
		end
	end

	Estado.aoMudar(function()
		if Navegacao.aberto() == "Presentes" then
			desenhar()
		end
	end)
	Navegacao.aoTrocar(function(nome)
		if nome == "Presentes" then
			desenhar()
		end
	end)
end

return Presentes
