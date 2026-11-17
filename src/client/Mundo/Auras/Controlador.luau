-- Liga e desliga os VFX de aura montados no cliente (Gear 5, Naruto, Monarca, Senbonzakura).
-- Quem decide qual aura está ativa é o SERVIDOR: ele grava o atributo "AuraVfx" no personagem
-- (e "AuraVfxEm" quando o jogador acabou de equipar, para tocar a manifestação).
-- Este cliente só observa esses atributos; não pede nem concede aura nenhuma.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AurasVfx =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Dados"):WaitForChild("AurasVfx"))
local Caudas = require(script.Parent.Caudas)
local Gear5 = require(script.Parent.Gear5)
local PresencaAnime = require(script.Parent.PresencaAnime)
local Monarca = require(script.Parent.Monarca)
local Senbonzakura = require(script.Parent.Senbonzakura)

local Controlador = {}

export type Preferencias = {
	qualidadeBaixa: boolean,
	movimentoReduzido: boolean,
	ocultarEfeitosAlheios: boolean,
}

type Ativo = { personagem: Model, id: string, inst: Gear5.Instancia }

type Modulo = { criar: (Model, Gear5.Opcoes) -> Gear5.Instancia? }
local MODULOS: { [string]: Modulo } = {
	gear5 = Gear5,
	monarca = Monarca,
	senbonzakura = Senbonzakura, -- templates clonados de ReplicatedStorage.AuraAssets (pipeline v2)
}
for _, id in Caudas.ORDEM do
	MODULOS[id] = Caudas.estagio(id)
end
local JANELA_MANIFESTAR = 2.5 -- segundos desde que o servidor marcou o equipar

local prefs: Preferencias =
	{ qualidadeBaixa = false, movimentoReduzido = false, ocultarEfeitosAlheios = false }
local ativos: { [Model]: Ativo } = {}
local montando: { [Model]: boolean } = {}
local encerrando: { Gear5.Instancia } = {} -- apagando (fade curto) até limparem tudo
local observados: { [Player]: { RBXScriptConnection } } = {}

local function permitido(jogador: Player): boolean
	return jogador == Players.LocalPlayer or not prefs.ocultarEfeitosAlheios
end

local function sincronizar(jogador: Player, personagem: Model)
	local id = personagem:GetAttribute("AuraVfx")
	local querido = if type(id) == "string"
			and AurasVfx[id]
			and MODULOS[id]
			and permitido(jogador)
		then id
		else nil
	-- Corpo e ambiente sao independentes da malha EditableMesh (podem funcionar
	-- mesmo quando o aparelho nao puder criar a nuvem 3D).
	if querido ~= "gear5" then
		PresencaAnime.definir(personagem, nil)
	else
		task.spawn(function()
			personagem:WaitForChild("HumanoidRootPart", 10)
			if personagem.Parent and personagem:GetAttribute("AuraVfx") == "gear5" and permitido(jogador) then
				PresencaAnime.definir(personagem, "gear5")
			end
		end)
	end
	local atual = ativos[personagem]
	if atual and atual.id == querido then
		return
	end
	if atual then
		atual.inst:encerrar(false) -- o laço termina de apagar e limpa
		table.insert(encerrando, atual.inst)
		ativos[personagem] = nil
	end
	if not querido or montando[personagem] then
		return
	end
	local em = personagem:GetAttribute("AuraVfxEm")
	local manifestar = type(em) == "number"
		and Workspace:GetServerTimeNow() - em < JANELA_MANIFESTAR
	montando[personagem] = true
	task.spawn(function()
		-- a primeira montagem converte as malhas (pode levar um instante)
		personagem:WaitForChild("HumanoidRootPart", 10)
		local ok, inst = pcall(MODULOS[querido].criar, personagem, {
			manifestar = manifestar,
			qualidadeBaixa = prefs.qualidadeBaixa,
			movimentoReduzido = prefs.movimentoReduzido,
			local_ = jogador == Players.LocalPlayer,
		})
		montando[personagem] = nil
		if not ok then
			warn("[Auras] falha ao montar " .. querido .. ": " .. tostring(inst))
			return
		end
		if not inst then
			return
		end
		-- algo mudou enquanto montava? confere de novo
		if
			personagem.Parent == nil
			or personagem:GetAttribute("AuraVfx") ~= querido
			or not permitido(jogador)
		then
			inst:encerrar(true)
			sincronizar(jogador, personagem)
			return
		end
		ativos[personagem] = { personagem = personagem, id = querido, inst = inst }
	end)
end

local function observar(jogador: Player)
	local lista: { RBXScriptConnection } = {}
	local function ligar(personagem: Model)
		sincronizar(jogador, personagem)
		table.insert(
			lista,
			personagem:GetAttributeChangedSignal("AuraVfx"):Connect(function()
				sincronizar(jogador, personagem)
			end)
		)
	end
	table.insert(lista, jogador.CharacterAdded:Connect(ligar))
	if jogador.Character then
		ligar(jogador.Character)
	end
	observados[jogador] = lista
end

function Controlador.definir(novas: Preferencias)
	local mudouQualidade = novas.qualidadeBaixa ~= prefs.qualidadeBaixa
		or novas.movimentoReduzido ~= prefs.movimentoReduzido
	local mudouAlheios = novas.ocultarEfeitosAlheios ~= prefs.ocultarEfeitosAlheios
	prefs = novas
	PresencaAnime.definirQualidade(prefs.qualidadeBaixa, prefs.movimentoReduzido)
	if mudouQualidade then
		for _, a in ativos do
			a.inst:definirQualidade(prefs.qualidadeBaixa, prefs.movimentoReduzido)
		end
	end
	if mudouAlheios then
		for _, jogador in Players:GetPlayers() do
			if jogador.Character then
				sincronizar(jogador, jogador.Character)
			end
		end
	end
end

function Controlador.iniciar()
	Players.PlayerAdded:Connect(observar)
	for _, jogador in Players:GetPlayers() do
		observar(jogador)
	end
	Players.PlayerRemoving:Connect(function(jogador)
		local lista = observados[jogador]
		for _, c in (lista or {}) :: { RBXScriptConnection } do
			c:Disconnect()
		end
		observados[jogador] = nil
		if jogador.Character then
			PresencaAnime.remover(jogador.Character)
		end
		if jogador.Character and ativos[jogador.Character] then
			ativos[jogador.Character].inst:encerrar(true)
			ativos[jogador.Character] = nil
		end
	end)
	-- O Animator aplica as poses primeiro; a presenca soma offsets antes da fisica.
	RunService.PreSimulation:Connect(PresencaAnime.simular)
	-- Um unico laço de VFX para auras e efeitos locais de superficie.
	RunService.PreRender:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local posicao = camera.CFrame.Position
		PresencaAnime.atualizar(dt, posicao)
		for personagem, a in ativos do
			if not a.inst:atualizar(dt, posicao) then
				ativos[personagem] = nil
			end
		end
		for i = #encerrando, 1, -1 do
			if not encerrando[i]:atualizar(dt, posicao) then
				table.remove(encerrando, i)
			end
		end
	end)
end

return Controlador
