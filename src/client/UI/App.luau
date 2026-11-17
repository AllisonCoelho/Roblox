-- Monta a interface do Despertar e controla o giro (manual e automático).
-- O cliente só pede: o resultado do sorteio sempre vem do servidor, já decidido e registrado.
-- A apresentação (Mundo/Despertar) é escolhida a partir desse resultado.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Apresentacao = require(Shared.Dados.Apresentacao)
local Auras = require(Shared.Dados.Auras)
local Config = require(Shared.Config)
local Monetizacao = require(Shared.Dados.Monetizacao)
local Remotos = require(Shared.Remotos)
local Escala = require(script.Parent.Escala)
local Estado = require(script.Parent.Estado)
local Navegacao = require(script.Parent.Navegacao)
local Telas = script.Parent:WaitForChild("Telas")
local Ajustes = require(Telas.Ajustes)
local ArenaUI = require(Telas.Arena)
local Altar = require(Telas.Altar)
local Avisos = require(Telas.Avisos)
local HUD = require(Telas.HUD)
local Indice = require(Telas.Indice)
local Inventario = require(Telas.Inventario)
local PainelDev = require(Telas.PainelDev)
local IncursoesUI = require(Telas.Incursoes)
local Revelacao = require(Telas.Revelacao)
local Mundo = script.Parent.Parent:WaitForChild("Mundo")
local Despertar = require(Mundo:WaitForChild("Despertar"))
local Artefatos = require(Mundo:WaitForChild("Artefatos"))
local AurasControlador = require(Mundo:WaitForChild("Auras"):WaitForChild("Controlador"))
local AurasCaudas = require(Mundo:WaitForChild("Auras"):WaitForChild("Caudas"))
local EfeitosAlheios = require(Mundo:WaitForChild("EfeitosAlheios"))

local App = {}

-- Pequena folga além do cooldown do servidor para não ter pedidos recusados
local FOLGA = 0.05
local INTERVALO = Config.CooldownGiro + FOLGA

local girando = false
local emIncursao = false
local emArena = false
local proximoGiro = 0
local ocupadoAte = 0 -- fim do ritual em andamento (auras sem cartão)
local hud: HUD.Api

local function preferencias(): Despertar.Preferencias
	local estado = Estado.atual
	return Despertar.preferencias(if estado then estado.configuracoes else nil)
end

-- Passes (o servidor liga o atributo "Passe_<id>" no jogador; aqui só lemos)
local function temPasse(id: string): boolean
	return Players.LocalPlayer:GetAttribute(Monetizacao.atributo(id)) == true
end

local ultimaOferta = 0
-- Mostra a compra do passe (ou "em breve" se o dono ainda não criou o passe no Creator Hub)
local function oferecer(id: string)
	if os.clock() - ultimaOferta < 4 then
		return
	end
	ultimaOferta = os.clock()
	local produto = Monetizacao.porId[id]
	if not produto then
		return
	end
	if produto.gamePassId then
		pcall(
			MarketplaceService.PromptGamePassPurchase,
			MarketplaceService,
			Players.LocalPlayer,
			produto.gamePassId
		)
	else
		Avisos.toast(
			string.format("%s · %d Robux — em breve na loja", produto.nome, produto.preco)
		)
	end
end

-- Pular o ritual é um passe; sem ele, o toque oferece a compra
local function pular()
	if temPasse("pularAnimacao") then
		Despertar.pular()
	else
		oferecer("pularAnimacao")
	end
end

local function podeGirar(): boolean
	local agora = os.clock()
	return Estado.atual ~= nil
		and Navegacao.aberto() == nil
		and not emIncursao
		and not emArena
		and not PainelDev.pendente()
		and not girando
		and not Revelacao.ativa()
		and not Altar.ativa()
		and agora >= proximoGiro
		and agora >= ocupadoAte
		-- o toque que fechou o cartão não deve virar um giro
		and agora - Revelacao.fimEm > 0.4
end

-- Encena um resultado já confirmado pelo servidor
local function apresentar(aura: Auras.Aura, dados: { [string]: any })
	local quantidade = if type(dados.quantidade) == "number" then dados.quantidade else 1
	local teste = dados.teste == true
	local simulado = dados.simulado == true
	local nova = quantidade <= 1 and not teste
	local chance = if type(dados.chance) == "number" then dados.chance else aura.chance
	local prefs = preferencias()
	local cat = Despertar.categoria(aura, not nova and not teste, prefs)
	local comCartao = cat.cartao > 0

	local function revelar()
		-- O ritual terminou ou foi pulado: a espera da apresentação acaba aqui
		-- (o cooldown do servidor, em proximoGiro, continua valendo)
		ocupadoAte = 0
		if not teste then
			hud.registrarResultado(aura, nova, simulado, chance)
			-- O anúncio de quem girou só aparece agora, para não entregar o resultado antes
			local jogador = Players.LocalPlayer
			local nome = if simulado then "[Teste] " .. jogador.DisplayName else jogador.DisplayName
			Avisos.anunciar(nome, jogador.UserId, aura, chance)
		end
		if comCartao and not emArena then
			local estado = Estado.atual
			Revelacao.mostrar(aura, cat, {
				quantidade = quantidade,
				chance = chance,
				equipada = dados.equipou == true or (estado ~= nil and estado.equipada == aura.id),
				teste = teste,
			})
		end
	end

	if emArena then
		revelar()
		return
	end

	-- Animações desligadas: nada de ritual nem câmera; o resultado (e o cartão) vem na hora
	if not prefs.animacoes then
		if comCartao then
			Revelacao.cena(false, 0)
		end
		revelar()
		return
	end

	ocupadoAte = os.clock() + Apresentacao.tempoAteRevelacao(cat)
	if comCartao then
		Revelacao.cena(
			cat.camera and not prefs.movimentoReduzido,
			if prefs.movimentoReduzido then 0.16 else 0.22
		)
	end
	Despertar.proprio(aura, cat, prefs, revelar)
end

local function girar()
	if not podeGirar() then
		return
	end
	girando = true
	proximoGiro = os.clock() + INTERVALO
	local ok, resposta, dados = Estado.pedir("Despertar")
	girando = false
	if ok and resposta then
		local aura = Auras.porId[resposta]
		if aura then
			apresentar(aura, dados or {})
		end
	elseif resposta then
		Avisos.toast(resposta)
	end
end

-- Botão DESPERTAR / tecla E: se há um ritual em andamento, o toque PULA a animação;
-- senão, gira. O giro automático nunca pula.
local function aoApertar()
	if Navegacao.aberto() then
		return
	end
	-- ocupadoAte só vale enquanto o ritual corre: revelar() o zera antes de abrir o cartão.
	-- Por isso a condição não olha Revelacao.ativa(): nas cenas raras a tela já está reservada
	-- desde o início, e era isso que impedia o pulo pela tecla.
	if not girando and os.clock() < ocupadoAte then
		pular()
		return
	end
	-- Com o cartão aberto, girar() não faz nada (a tecla não fecha o cartão nem gira de novo)
	girar()
end

-- Só no Studio: Alt+1..6 encena uma categoria sem sortear nem salvar nada
local function testeVisual(indice: number)
	if not podeGirar() then
		return
	end
	task.spawn(function()
		local ok, resposta, dados = Estado.pedir("TesteVisual", indice)
		local aura = if ok and resposta then Auras.porId[resposta] else nil
		if aura then
			apresentar(aura, dados or { teste = true })
		elseif resposta then
			Avisos.toast(resposta)
		end
	end)
end

local function alternarConfiguracao(chave: string)
	local estado = Estado.atual
	if not estado then
		return
	end
	task.spawn(function()
		local ok, msg = Estado.pedir("Configurar", chave, not estado.configuracoes[chave])
		if not ok and msg then
			Avisos.toast(msg)
		end
	end)
end

-- Alguém do servidor tirou uma aura 1 em 1.000 ou mais rara
local function aoDespertou(dados: any)
	if type(dados) ~= "table" or type(dados.aura) ~= "string" or type(dados.userId) ~= "number" then
		return
	end
	local aura = Auras.porId[dados.aura]
	if not aura then
		return
	end
	-- Quem girou vê a versão completa e recebe o próprio anúncio só na revelação
	-- (em apresentar/revelar): aqui o evento chega antes do ritual terminar
	if dados.userId == Players.LocalPlayer.UserId then
		return
	end
	local jogador = Players:GetPlayerByUserId(dados.userId)
	if jogador then
		Despertar.alheio(jogador, aura, preferencias())
	end
	if type(dados.jogador) == "string" then
		Avisos.anunciar(
			dados.jogador,
			dados.userId,
			aura,
			if type(dados.chance) == "number" then dados.chance else nil
		)
	end
end

function App.iniciar()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Despertar"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local raiz = Escala.montar(gui)
	Navegacao.montar(raiz)
	hud = HUD.montar(raiz, {
		aoDespertar = function()
			task.spawn(aoApertar)
		end,
		aoAlternarAuto = function()
			local estado = Estado.atual
			local ligando = estado ~= nil and not estado.configuracoes.giroAutomatico
			if ligando and not temPasse("autoGiro") then
				oferecer("autoGiro")
				return
			end
			alternarConfiguracao("giroAutomatico")
		end,
		aoAbrirIndice = Indice.abrir,
		aoAbrirInventario = Inventario.abrir,
		aoAbrirAjustes = Ajustes.abrir,
	})
	Revelacao.montar(raiz, {
		aoEquipar = function(auraId)
			task.spawn(function()
				local ok, msg = Estado.pedir("Equipar", auraId)
				if not ok and msg then
					Avisos.toast(msg)
				end
			end)
		end,
		aoPular = pular,
		aoMudar = function(ativa)
			hud.definirVisivel(not ativa and not emIncursao and not emArena)
		end,
	})
	Avisos.montar(raiz)
	Indice.montar(Avisos.toast)
	Inventario.montar(Avisos.toast)
	Altar.montar(raiz, Avisos.toast)
	Ajustes.montar(Avisos.toast)
	PainelDev.iniciar(hud.quadro, {
		podeAbrir = function()
			return not girando
				and not emIncursao
				and not emArena
				and not Revelacao.ativa()
				and os.clock() >= ocupadoAte
		end,
		aoRitual = function(id, dados)
			local aura = Auras.porId[id]
			if aura then
				proximoGiro = math.max(proximoGiro, os.clock() + INTERVALO)
				apresentar(aura, dados)
			end
		end,
	})
	IncursoesUI.montar(raiz, Avisos.toast, function(emPartida)
		emIncursao = emPartida
		if emPartida then
			Despertar.pular()
			Revelacao.fechar()
		end
		hud.definirVisivel(not emPartida and not emArena and not Revelacao.ativa())
	end)
	ArenaUI.montar(raiz, Avisos.toast, function(emDuelo)
		emArena = emDuelo
		if emDuelo then
			Navegacao.fechar()
			Despertar.pular()
			Revelacao.fechar()
			ocupadoAte = 0
		end
		hud.definirVisivel(not emDuelo and not emIncursao and not Revelacao.ativa())
	end)
	Navegacao.ajustar()

	EfeitosAlheios.iniciar()
	AurasControlador.iniciar()
	Artefatos.iniciar()
	Estado.aoMudar(function(estado)
		hud.atualizar(estado)
		local c = estado.configuracoes
		Artefatos.definir(
			estado.inventario.equipados.artefato,
			c.qualidadeBaixa == true,
			c.ocultarEfeitosAlheios == true
		)
		EfeitosAlheios.definir(c.ocultarEfeitosAlheios == true)
		IncursoesUI.definirQualidade(c.qualidadeBaixa == true, c.movimentoReduzido == true)
		AurasControlador.definir({
			qualidadeBaixa = c.qualidadeBaixa == true,
			movimentoReduzido = c.movimentoReduzido == true,
			ocultarEfeitosAlheios = c.ocultarEfeitosAlheios == true,
		})
	end)
	local jogador = Players.LocalPlayer
	local function atualizarPerfilTeste()
		hud.definirPerfilTeste(jogador:GetAttribute("PerfilDeTeste") == true)
	end
	jogador:GetAttributeChangedSignal("PerfilDeTeste"):Connect(atualizarPerfilTeste)
	atualizarPerfilTeste()
	Estado.iniciar()
	Remotos.evento("Despertou").OnClientEvent:Connect(aoDespertou)

	-- Se o personagem renascer no meio de uma cena, a tela não pode ficar presa
	Players.LocalPlayer.CharacterAdded:Connect(function()
		Revelacao.fechar()
	end)

	-- A mesma espera que bloqueia o giro controla o aro e a indicação de recarga.
	RunService.RenderStepped:Connect(function()
		local agora = os.clock()
		local falta = math.max(0, proximoGiro - agora, Revelacao.fimEm + 0.4 - agora)
		local estado: HUD.EstadoGiro = if not Estado.atual
			then "perfil"
			elseif girando then "pedido"
			elseif agora < ocupadoAte then "pular"
			elseif falta > 0 then "recarregando"
			else "pronto"
		local fracao = if estado == "perfil" or estado == "pedido"
			then 0
			else 1 - math.min(falta / INTERVALO, 1)
		hud.definirGiro(fracao, falta, estado)
	end)

	UserInputService.InputBegan:Connect(function(input, processado)
		if processado or emArena then
			return
		end
		if input.KeyCode == Enum.KeyCode.E and not emIncursao then
			task.spawn(aoApertar)
		elseif
			RunService:IsStudio()
			and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
			and input.KeyCode == Enum.KeyCode.G
		then
			-- Só no Studio: Alt+G liga/desliga a prévia da Gear 5 (sem posse nem save)
			task.spawn(function()
				local _, msg = Estado.pedir("PreviaAura", "gear5")
				if msg then
					Avisos.toast(msg)
				end
			end)
		elseif
			RunService:IsStudio()
			and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
			and input.KeyCode == Enum.KeyCode.M
		then
			-- Só no Studio: Alt+M liga/desliga a prévia do Monarca das Sombras
			task.spawn(function()
				local _, msg = Estado.pedir("PreviaAura", "monarca")
				if msg then
					Avisos.toast(msg)
				end
			end)
		elseif
			RunService:IsStudio()
			and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
			and input.KeyCode == Enum.KeyCode.N
		then
			-- Só no Studio: Alt+N passa pelos estágios Naruto (2 caudas ... 9 caudas, Seis Caminhos, nenhum)
			task.spawn(function()
				local personagem = Players.LocalPlayer.Character
				local atual = if personagem then personagem:GetAttribute("AuraVfx") else nil
				local ordem = AurasCaudas.ORDEM
				local proximo = ordem[1]
				for i, id in ordem do
					if id == atual then
						-- depois do último, o mesmo id de novo desliga a prévia
						proximo = ordem[i + 1] or id
					end
				end
				local _, msg = Estado.pedir("PreviaAura", proximo)
				if msg then
					Avisos.toast(msg)
				end
			end)
		elseif RunService:IsStudio() and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
			local indice = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
			if indice >= 1 and indice <= #Apresentacao.Categorias then
				testeVisual(indice)
			end
		end
	end)

	-- Giro automático: mesma rotina e mesmo cooldown do giro manual
	task.spawn(function()
		while true do
			task.wait(0.1)
			local estado = Estado.atual
			if
				estado
				and estado.configuracoes.giroAutomatico
				and temPasse("autoGiro")
				and podeGirar()
			then
				task.spawn(girar)
			end
		end
	end)
end

return App
