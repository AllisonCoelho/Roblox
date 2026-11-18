local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icones = require(ReplicatedStorage.Shared.Dados.Icones)
local Remotos = require(ReplicatedStorage.Shared.Remotos)
local Escala = require(script.Parent.Parent.Escala)
local Estado = require(script.Parent.Parent.Estado)
local Kit = require(script.Parent.Parent.Kit)
local Navegacao = require(script.Parent.Parent.Navegacao)

local NOME = "DialogoSoberano"
local DialogoSoberano = {}

function DialogoSoberano.aberto(): boolean
	return Navegacao.aberto() == NOME
end

function DialogoSoberano.montar(aoAviso: (string) -> (), aoAbrir: () -> ())
	local painel = Navegacao.criarPainel(NOME, {
		titulo = "Primeiro Soberano",
		icone = Icones.DISTINTIVOS.dis_coroa,
		dimensoes = Vector2.new(700, 320),
	})
	local fala = Kit.texto({
		Text = "“O trono pertence a quem consegue defendê-lo. Veio me desafiar?”",
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(20, 4),
		Size = UDim2.new(1, -40, 0.42, -8),
		Parent = painel.conteudo,
	})
	Kit.novo("UITextSizeConstraint", { MaxTextSize = 24, Parent = fala })
	local convite: number? = nil
	local pendente = false
	local botoes: { Kit.BotaoPlaca } = {}

	local function habilitar(ativo: boolean)
		for _, botao in botoes do
			botao.botao.Interactable = ativo
			botao.botao.Selectable = ativo
		end
	end

	local function responder(resposta: string)
		local id = convite
		if not id or pendente or not DialogoSoberano.aberto() then
			return
		end
		pendente = true
		habilitar(false)
		task.spawn(function()
			local ok, msg = Estado.pedir("ArenaResponder", id, resposta)
			if convite ~= id or not DialogoSoberano.aberto() then
				return
			end
			convite = nil
			painel.fechar()
			if not ok and msg then
				aoAviso(msg)
			end
		end)
	end

	local function botao(texto: string, resposta: string, tom: Kit.Tom, y: number)
		local item = Kit.botaoPlaca({
			texto = texto,
			tamanho = UDim2.new(1, -40, 0.29, -8),
			tom = tom,
			pai = painel.conteudo,
			aoClicar = function()
				responder(resposta)
			end,
		})
		item.placa.quadro.Position = UDim2.new(0, 20, y, 0)
		item.rotulo.TextScaled = true
		Kit.novo("UITextSizeConstraint", { MaxTextSize = 22, Parent = item.rotulo })
		table.insert(botoes, item)
		return item.botao
	end

	local duelar = botao("Eu te desafio pelo trono.", "duelar", "lilas", 0.42)
	local fugir = botao("Hoje não. Vou embora.", "fugir", "neutro", 0.71)
	duelar.NextSelectionDown = fugir
	fugir.NextSelectionUp = duelar

	Players.LocalPlayer.CharacterRemoving:Connect(function()
		if DialogoSoberano.aberto() then
			convite = nil
			painel.fechar()
		end
	end)
	Remotos.evento("Arena").OnClientEvent:Connect(function(pacote)
		if pacote.tipo ~= "dialogo" then
			return
		end
		local restante = pacote.prazo - workspace:GetServerTimeNow()
		if restante <= 0 then
			return
		end
		local id = pacote.id
		convite = id
		pendente = false
		habilitar(true)
		Navegacao.abrir(NOME)
		if Escala.controle then
			GuiService.SelectedObject = fugir
		end
		aoAbrir()
		task.delay(restante, function()
			if convite == id then
				convite = nil
				if DialogoSoberano.aberto() then
					painel.fechar()
				end
			end
		end)
	end)
end

return DialogoSoberano
