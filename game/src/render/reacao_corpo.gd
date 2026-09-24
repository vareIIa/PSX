## O que a pessoa faz quando o jogador troca alguma coisa nela.
##
## Trocou a camisa: ela olha para o peito e puxa a barra. Trocou o chapeu: leva
## a mao a aba. Trocou o rosto: mao no queixo, cabeca inclinada, "hm". E a
## diferenca entre um manequim girando num pedestal e alguem experimentando
## roupa — e a tela de criacao e o primeiro lugar do jogo em que o jogador ve o
## proprio corpo de perto.
##
## Como a reacao entra na pose
## ---------------------------
## Por CIMA da pose parada, e nao no lugar dela. `Corpo._aplicar_pose` monta a
## pose de sempre e depois chama `aplicar`, que gira so os ossos que a reacao
## usa, do angulo que estava ate o angulo da reacao, por um envelope: sobe em um
## quarto do tempo, segura, desce no ultimo quarto. Quem nao esta na tabela
## continua respirando.
##
## Travada em passos, como o resto
## -------------------------------
## Quinze poses por segundo, a mesma grade do ciclo de caminhada. Uma mao
## deslizando lisa ate o rosto ao lado de um corpo que anda em quinze poses por
## ciclo le como animacao de outro jogo colada neste.
##
## De onde vem os numeros
## ----------------------
## Os ALVOS sao pontos do corpo de referencia (1,72 m): o queixo, a aba do bone,
## a barra da camisa. Os angulos de ombro e cotovelo que levam o centro da mao
## ate cada alvo sairam de `tests/medir_reacao.gd --resolver`, e o mesmo teste
## sem a bandeira confere que a mao chega. Mexeu num alvo: rode o resolvedor.
class_name ReacaoCorpo
extends RefCounted

enum {
	NENHUMA, ROSTO, CABELO, ROUPA, AGASALHO, PERNAS, PES, CHAPEU, OCULOS,
	BARBA, CORPO, PELE, APROVADO, OCIO_PESO, OCIO_OLHAR, OCIO_RELOGIO,
	# Gestos do jogo: ocio da rua, fala e reacao (PLANO_PERSONAGENS_AAA, fases
	# 3 e 4). No fim do enum, para os indices da criacao nao mudarem.
	OCIO_CRUZA, OCIO_CINTURA, OCIO_BOLSO, OCIO_NUCA, OCIO_CELULAR, OCIO_ESPREGUICA,
	OCIO_BOCEJO, OCIO_BENZE, OCIO_ESFREGA, OCIO_CEU, OCIO_ATRAS,
	GESTO_EXPLICA, GESTO_ABRE, GESTO_OMBROS, GESTO_PEITO, GESTO_APONTA, GESTO_ACENO,
	GESTO_NEGA, GESTO_CONCORDA,
	REACAO_PROTEGE, REACAO_MAOS_ALTO, REACAO_XINGA,
	REACAO_DOR_CABECA, REACAO_DOR_COSTAS, REACAO_DOR_BARRIGA, REACAO_DOR_BRACO,
	REACAO_MAO_NA_CABECA,
}

## Os gestos de quem esta parado esperando. Nenhum campo dispara: e o retrato
## que sorteia um deles de tempos em tempos, quando ninguem mexe em nada.
const OCIOSAS: Array[int] = [OCIO_PESO, OCIO_OLHAR, OCIO_RELOGIO]

const PASSOS_POR_SEGUNDO := 15.0

## Braco direito e o de +X: a pessoa olha para -Z, e a direita dela e +X.
const D := 1
const E := -1

const POSES := {
	ROSTO: {
		"nome": "rosto", "duracao": 1.9,
		# Pose de quem pensa: a mao direita no queixo, a esquerda cruzada na
		# barriga segurando o cotovelo.
		"alvos": {D: Vector3(0.03, 1.46, -0.16), E: Vector3(0.12, 1.12, -0.17)},
		"cotovelos": {D: Vector3(0.14, 1.16, -0.16), E: Vector3(-0.22, 1.10, -0.06)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(0.02, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(0.76, 1.10, 0.56),
			Corpo.Osso.ANTEBRACO_D: Vector3(2.11, 0.0, 0.0),
			Corpo.Osso.BRACO_E: Vector3(0.31, -1.42, -0.33),
			Corpo.Osso.ANTEBRACO_E: Vector3(1.24, 0.0, 0.0),
		},
		"cabeca": Vector3(-0.06, -0.10, 0.10),
	},
	CABELO: {
		"nome": "cabelo", "duracao": 1.7,
		"alvos": {D: Vector3(0.15, 1.68, -0.02)},
		"cotovelos": {D: Vector3(0.36, 1.56, 0.02)},
		"ossos": {
			Corpo.Osso.BRACO_D: Vector3(2.38, -1.67, -0.07),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.89, 0.0, 0.0),
		},
		"cabeca": Vector3(0.10, 0.0, 0.14),
	},
	ROUPA: {
		"nome": "roupa", "duracao": 1.9,
		# Olha o peito e puxa a barra com as duas maos.
		"alvos": {D: Vector3(0.13, 1.00, -0.17), E: Vector3(-0.13, 1.00, -0.17)},
		"cotovelos": {D: Vector3(0.24, 1.12, 0.03), E: Vector3(-0.24, 1.12, 0.03)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(-0.06, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(-0.32, 0.37, -0.10),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.56, 0.0, 0.0),
			Corpo.Osso.BRACO_E: Vector3(-0.32, -0.37, 0.10),
			Corpo.Osso.ANTEBRACO_E: Vector3(1.56, 0.0, 0.0),
		},
		"cabeca": Vector3(0.42, 0.0, 0.0),
	},
	AGASALHO: {
		"nome": "agasalho", "duracao": 1.7,
		# As duas maos nas lapelas, ajeitando a gola.
		"alvos": {D: Vector3(0.08, 1.28, -0.19), E: Vector3(-0.08, 1.28, -0.19)},
		"cotovelos": {D: Vector3(0.24, 1.12, -0.06), E: Vector3(-0.24, 1.12, -0.06)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(0.04, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(0.09, 0.60, -0.04),
			Corpo.Osso.ANTEBRACO_D: Vector3(2.16, 0.0, 0.0),
			Corpo.Osso.BRACO_E: Vector3(0.09, -0.60, 0.04),
			Corpo.Osso.ANTEBRACO_E: Vector3(2.16, 0.0, 0.0),
		},
		"cabeca": Vector3(0.22, 0.0, 0.0),
	},
	PERNAS: {
		"nome": "pernas", "duracao": 1.9,
		# Curva e passa a mao nas coxas, olhando a calca.
		"alvos": {D: Vector3(0.15, 0.76, -0.13), E: Vector3(-0.15, 0.76, -0.13)},
		"cotovelos": {D: Vector3(0.25, 1.00, -0.08), E: Vector3(-0.25, 1.00, -0.08)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(-0.30, 0.0, 0.0),
			Corpo.Osso.QUADRIL: Vector3(-0.06, 0.0, 0.0),
			Corpo.Osso.COXA_E: Vector3(0.10, 0.0, 0.0),
			Corpo.Osso.COXA_D: Vector3(0.10, 0.0, 0.0),
			Corpo.Osso.CANELA_E: Vector3(-0.16, 0.0, 0.0),
			Corpo.Osso.CANELA_D: Vector3(-0.16, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(0.28, 0.84, 0.19),
			Corpo.Osso.ANTEBRACO_D: Vector3(0.16, 0.0, 0.0),
			Corpo.Osso.BRACO_E: Vector3(0.28, -0.84, -0.19),
			Corpo.Osso.ANTEBRACO_E: Vector3(0.16, 0.0, 0.0),
		},
		"quadril": Vector3(0.0, -0.02, 0.03),
		"cabeca": Vector3(0.30, 0.0, 0.0),
	},
	PES: {
		"nome": "pes", "duracao": 1.9,
		# Maos na cintura, o pe direito para a frente, olhando o sapato.
		"alvos": {D: Vector3(0.20, 0.98, -0.02), E: Vector3(-0.20, 0.98, -0.02)},
		"cotovelos": {D: Vector3(0.40, 1.12, 0.05), E: Vector3(-0.40, 1.12, 0.05)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(-0.08, 0.0, 0.0),
			Corpo.Osso.COXA_D: Vector3(0.38, 0.0, -0.04),
			Corpo.Osso.CANELA_D: Vector3(-0.22, 0.0, 0.0),
			Corpo.Osso.COXA_E: Vector3(-0.04, 0.0, 0.03),
			Corpo.Osso.BRACO_D: Vector3(-0.78, 1.09, 0.02),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.65, 0.0, 0.0),
			Corpo.Osso.BRACO_E: Vector3(-0.78, -1.09, -0.02),
			Corpo.Osso.ANTEBRACO_E: Vector3(1.65, 0.0, 0.0),
		},
		"cabeca": Vector3(0.50, -0.18, 0.0),
	},
	CHAPEU: {
		"nome": "chapeu", "duracao": 1.5,
		# A mao na LATERAL da aba, e nao na frente. Com a camera na cara, o
		# braco subindo pela frente passava entre a lente e o rosto e a foto
		# inteira virava manga.
		"alvos": {D: Vector3(0.16, 1.71, -0.09)},
		"cotovelos": {D: Vector3(0.38, 1.50, -0.04)},
		"ossos": {
			Corpo.Osso.BRACO_D: Vector3(0.93, 2.12, 2.64),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.71, 0.0, 0.0),
		},
		"cabeca": Vector3(0.14, 0.0, 0.0),
	},
	OCULOS: {
		"nome": "oculos", "duracao": 1.4,
		# A mao na haste, ao lado do olho. Na ponte do nariz ela cobria o
		# rosto justamente no enquadramento em que se escolhem oculos.
		"alvos": {D: Vector3(0.14, 1.60, -0.10)},
		"cotovelos": {D: Vector3(0.32, 1.32, -0.08)},
		"ossos": {
			Corpo.Osso.BRACO_D: Vector3(0.99, 1.56, 2.11),
			Corpo.Osso.ANTEBRACO_D: Vector3(2.13, 0.0, 0.0),
		},
		"cabeca": Vector3(-0.08, 0.0, 0.0),
	},
	BARBA: {
		"nome": "barba", "duracao": 1.7,
		"alvos": {D: Vector3(0.0, 1.43, -0.16)},
		"cotovelos": {D: Vector3(0.18, 1.18, -0.14)},
		"ossos": {
			Corpo.Osso.BRACO_D: Vector3(0.68, 1.16, 0.46),
			Corpo.Osso.ANTEBRACO_D: Vector3(2.08, 0.0, 0.0),
		},
		"cabeca": Vector3(-0.14, 0.06, 0.0),
	},
	CORPO: {
		"nome": "corpo", "duracao": 1.8,
		# Os dois biceps. E o gesto que qualquer um faz para ver o proprio porte.
		"alvos": {D: Vector3(0.42, 1.62, -0.04), E: Vector3(-0.42, 1.62, -0.04)},
		"cotovelos": {D: Vector3(0.48, 1.38, 0.0), E: Vector3(-0.48, 1.38, 0.0)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(0.07, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(1.36, -0.23, 1.17),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.87, 0.0, 0.0),
			Corpo.Osso.BRACO_E: Vector3(1.36, 0.23, -1.17),
			Corpo.Osso.ANTEBRACO_E: Vector3(1.87, 0.0, 0.0),
		},
		"cabeca": Vector3(0.0, -0.30, 0.0),
	},
	PELE: {
		"nome": "pele", "duracao": 1.7,
		# Olha o dorso da propria mao, virando-a na frente do rosto.
		"alvos": {D: Vector3(0.10, 1.40, -0.32)},
		"cotovelos": {D: Vector3(0.24, 1.18, -0.14)},
		"ossos": {
			Corpo.Osso.BRACO_D: Vector3(0.72, 0.53, 0.27),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.81, 0.0, 0.0),
		},
		"cabeca": Vector3(0.24, -0.28, 0.0),
	},
	APROVADO: {
		"nome": "aprovado", "duracao": 1.8,
		# Joinha na altura do peito: a pessoa aprova o documento que acabou de
		# ser emitido. E a despedida da tela.
		"alvos": {D: Vector3(0.14, 1.34, -0.24)},
		"cotovelos": {D: Vector3(0.26, 1.12, -0.06)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(0.04, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(0.32, 0.30, -0.04),
			Corpo.Osso.ANTEBRACO_D: Vector3(2.14, 0.0, 0.0),
		},
		"cabeca": Vector3(-0.08, -0.06, 0.08),
	},
	OCIO_PESO: {
		"nome": "ocio_peso", "duracao": 2.6,
		# O peso vai para uma perna, a outra dobra o joelho. Sem braco nenhum:
		# e o gesto de quem nem percebe que mexeu.
		"ossos": {
			Corpo.Osso.QUADRIL: Vector3(0.0, 0.0, 0.07),
			Corpo.Osso.TORSO: Vector3(0.0, 0.0, -0.06),
			Corpo.Osso.COXA_D: Vector3(0.10, 0.0, -0.05),
			Corpo.Osso.CANELA_D: Vector3(-0.28, 0.0, 0.0),
			Corpo.Osso.COXA_E: Vector3(0.0, 0.0, -0.07),
		},
		"quadril": Vector3(0.025, -0.012, 0.0),
		"cabeca": Vector3(0.0, 0.0, -0.05),
	},
	OCIO_OLHAR: {
		"nome": "ocio_olhar", "duracao": 2.4,
		# So a cabeca: olha para um lado, depois para o outro. O giro vem do
		# gesto secundario em `aplicar`.
		"ossos": {
			Corpo.Osso.TORSO: Vector3(0.0, 0.0, 0.0),
		},
		"cabeca": Vector3(-0.04, 0.0, 0.0),
	},
	OCIO_RELOGIO: {
		"nome": "ocio_relogio", "duracao": 2.2,
		# Confere o relogio: o pulso esquerdo sobe na frente do peito e a
		# cabeca desce para ele.
		"alvos": {E: Vector3(-0.02, 1.20, -0.26)},
		"cotovelos": {E: Vector3(-0.24, 1.12, -0.08)},
		"ossos": {
			Corpo.Osso.BRACO_E: Vector3(0.22, -0.64, 0.04),
			Corpo.Osso.ANTEBRACO_E: Vector3(1.71, 0.0, 0.0),
		},
		"cabeca": Vector3(0.36, 0.20, 0.0),
	},
	# --- gestos do jogo (ocio, fala, reacao) ---
	OCIO_CRUZA: {
		"nome": "ocio_cruza", "duracao": 4.0,
		# Bracos cruzados na frente do peito: cada mao no cotovelo do outro lado.
		"alvos": {D: Vector3(-0.13, 1.13, -0.17), E: Vector3(0.13, 1.15, -0.16)},
		"cotovelos": {D: Vector3(0.22, 1.10, -0.12), E: Vector3(-0.22, 1.12, -0.10)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(0.03, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(-0.82, 2.35, 1.41),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.16, 0.0, 0.0),
			Corpo.Osso.BRACO_E: Vector3(-1.20, -2.18, -1.89),
			Corpo.Osso.ANTEBRACO_E: Vector3(1.24, 0.0, 0.0),
		},
		"cabeca": Vector3(-0.04, 0.00, 0.00),
	},
	OCIO_CINTURA: {
		"nome": "ocio_cintura", "duracao": 4.0,
		# Maos na cintura, cotovelos para fora: o mandao parado.
		"alvos": {D: Vector3(0.20, 1.02, -0.02), E: Vector3(-0.20, 1.02, -0.02)},
		"cotovelos": {D: Vector3(0.38, 1.12, 0.04), E: Vector3(-0.38, 1.12, 0.04)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(0.02, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(-0.84, 1.17, 0.03),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.83, 0.0, 0.0),
			Corpo.Osso.BRACO_E: Vector3(-0.84, -1.17, -0.03),
			Corpo.Osso.ANTEBRACO_E: Vector3(1.83, 0.0, 0.0),
		},
		"cabeca": Vector3(-0.06, 0.00, 0.00),
	},
	OCIO_BOLSO: {
		"nome": "ocio_bolso", "duracao": 4.5,
		# Maos nos bolsos da frente: a mao entra na calca e some, que e o bolso.
		"alvos": {D: Vector3(0.16, 0.88, -0.08), E: Vector3(-0.16, 0.88, -0.08)},
		"cotovelos": {D: Vector3(0.25, 1.08, 0.05), E: Vector3(-0.25, 1.08, 0.05)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(0.00, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(-0.29, 0.60, -0.04),
			Corpo.Osso.ANTEBRACO_D: Vector3(0.99, 0.0, 0.0),
			Corpo.Osso.BRACO_E: Vector3(-0.29, -0.60, 0.04),
			Corpo.Osso.ANTEBRACO_E: Vector3(0.99, 0.0, 0.0),
		},
		"cabeca": Vector3(0.06, 0.00, 0.00),
	},
	OCIO_NUCA: {
		"nome": "ocio_nuca", "duracao": 2.4,
		# Coca a nuca, cabeca baixa: sem graca, pensando.
		"alvos": {D: Vector3(0.05, 1.56, 0.10)},
		"cotovelos": {D: Vector3(0.30, 1.62, -0.06)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(0.00, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(0.37, 2.42, 2.56),
			Corpo.Osso.ANTEBRACO_D: Vector3(2.05, 0.0, 0.0),
		},
		"cabeca": Vector3(0.18, 0.00, 0.08),
	},
	OCIO_CELULAR: {
		"nome": "ocio_celular", "duracao": 4.0,
		# As duas maos na frente do peito, olhando para baixo: o celular.
		"alvos": {D: Vector3(0.04, 1.17, -0.27), E: Vector3(-0.03, 1.15, -0.26)},
		"cotovelos": {D: Vector3(0.22, 1.06, -0.06), E: Vector3(-0.22, 1.05, -0.06)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(-0.02, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(-0.08, 1.22, 0.85),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.66, 0.0, 0.0),
			Corpo.Osso.BRACO_E: Vector3(0.13, -0.91, -0.30),
			Corpo.Osso.ANTEBRACO_E: Vector3(1.62, 0.0, 0.0),
		},
		"cabeca": Vector3(0.40, 0.00, 0.00),
	},
	OCIO_ESPREGUICA: {
		"nome": "ocio_espreguica", "duracao": 2.6,
		# Bracos para o alto, tronco para tras: espreguicando.
		"alvos": {D: Vector3(0.17, 1.90, -0.01), E: Vector3(-0.17, 1.90, -0.01)},
		"cotovelos": {D: Vector3(0.32, 1.78, 0.00), E: Vector3(-0.32, 1.78, 0.00)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(0.10, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(2.68, 0.39, -0.04),
			Corpo.Osso.ANTEBRACO_D: Vector3(0.46, 0.0, 0.0),
			Corpo.Osso.BRACO_E: Vector3(2.68, -0.39, 0.04),
			Corpo.Osso.ANTEBRACO_E: Vector3(0.46, 0.0, 0.0),
		},
		"cabeca": Vector3(-0.25, 0.00, 0.00),
	},
	OCIO_BOCEJO: {
		"nome": "ocio_bocejo", "duracao": 2.2,
		# Mao na boca, cabeca para tras. O Rosto abre a boca e fecha o olho junto.
		"alvos": {D: Vector3(0.02, 1.54, -0.17)},
		"cotovelos": {D: Vector3(0.20, 1.28, -0.14)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(0.04, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(1.02, 1.36, 0.86),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.85, 0.0, 0.0),
		},
		"cabeca": Vector3(-0.18, 0.00, 0.00),
	},
	OCIO_BENZE: {
		"nome": "ocio_benze", "duracao": 2.4,
		# Se benze: a mao vai a testa e desce ao peito (o gesto secundario).
		"alvos": {D: Vector3(0.00, 1.60, -0.15)},
		"cotovelos": {D: Vector3(0.22, 1.30, -0.12)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(-0.02, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(1.33, 1.69, 0.82),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.73, 0.0, 0.0),
		},
		"cabeca": Vector3(0.12, 0.00, 0.00),
	},
	OCIO_ESFREGA: {
		"nome": "ocio_esfrega", "duracao": 2.6,
		# Esfrega as maos na frente da barriga: o vigarista tramando.
		"alvos": {D: Vector3(0.03, 1.03, -0.23), E: Vector3(-0.03, 1.03, -0.23)},
		"cotovelos": {D: Vector3(0.22, 1.07, -0.05), E: Vector3(-0.22, 1.07, -0.05)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(-0.03, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(0.03, 1.08, 0.30),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.30, 0.0, 0.0),
			Corpo.Osso.BRACO_E: Vector3(0.03, -1.08, -0.30),
			Corpo.Osso.ANTEBRACO_E: Vector3(1.30, 0.0, 0.0),
		},
		"cabeca": Vector3(0.10, 0.00, 0.00),
	},
	OCIO_CEU: {
		"nome": "ocio_ceu", "duracao": 2.8,
		# Olha para o alto, sem braco: o sonhador.
		"ossos": {
			Corpo.Osso.TORSO: Vector3(0.04, 0.0, 0.0),
		},
		"cabeca": Vector3(-0.45, 0.00, 0.00),
	},
	OCIO_ATRAS: {
		"nome": "ocio_atras", "duracao": 4.0,
		# Maos juntas nas costas: o devoto andando, o velho olhando a obra.
		"alvos": {D: Vector3(0.05, 0.98, 0.17), E: Vector3(-0.05, 0.98, 0.17)},
		"cotovelos": {D: Vector3(0.24, 1.08, 0.10), E: Vector3(-0.24, 1.08, 0.10)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(0.02, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(-0.07, 2.15, -0.11),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.25, 0.0, 0.0),
			Corpo.Osso.BRACO_E: Vector3(-0.07, -2.15, 0.11),
			Corpo.Osso.ANTEBRACO_E: Vector3(1.25, 0.0, 0.0),
		},
		"cabeca": Vector3(0.02, 0.00, 0.00),
	},
	GESTO_EXPLICA: {
		"nome": "gesto_explica", "duracao": 1.4,
		# Palma aberta para a frente, marcando a frase.
		"alvos": {D: Vector3(0.18, 1.12, -0.34)},
		"cotovelos": {D: Vector3(0.25, 1.03, -0.08)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(-0.02, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(0.06, 0.64, 0.56),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.48, 0.0, 0.0),
		},
		"cabeca": Vector3(0.00, 0.00, 0.00),
	},
	GESTO_ABRE: {
		"nome": "gesto_abre", "duracao": 1.5,
		# Bracos abertos: 'e ai?', 'olha isso!'.
		"alvos": {D: Vector3(0.46, 1.12, -0.20), E: Vector3(-0.46, 1.12, -0.20)},
		"cotovelos": {D: Vector3(0.34, 1.15, -0.02), E: Vector3(-0.34, 1.15, -0.02)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(0.03, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(-0.08, -0.35, 0.56),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.59, 0.0, 0.0),
			Corpo.Osso.BRACO_E: Vector3(-0.08, 0.35, -0.56),
			Corpo.Osso.ANTEBRACO_E: Vector3(1.59, 0.0, 0.0),
		},
		"cabeca": Vector3(-0.06, 0.00, 0.00),
	},
	GESTO_OMBROS: {
		"nome": "gesto_ombros", "duracao": 1.3,
		# Da de ombros: maos para fora, palmas para cima, cabeca de lado.
		"alvos": {D: Vector3(0.30, 1.00, -0.22), E: Vector3(-0.30, 1.00, -0.22)},
		"cotovelos": {D: Vector3(0.26, 1.08, 0.00), E: Vector3(-0.26, 1.08, 0.00)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(0.02, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(-0.16, -0.17, 0.08),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.38, 0.0, 0.0),
			Corpo.Osso.BRACO_E: Vector3(-0.16, 0.17, -0.08),
			Corpo.Osso.ANTEBRACO_E: Vector3(1.38, 0.0, 0.0),
		},
		"cabeca": Vector3(0.00, 0.00, 0.14),
	},
	GESTO_PEITO: {
		"nome": "gesto_peito", "duracao": 1.5,
		# Mao no peito: 'eu'.
		"alvos": {D: Vector3(-0.03, 1.27, -0.19)},
		"cotovelos": {D: Vector3(0.20, 1.10, -0.10)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(0.02, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(0.31, 1.13, 0.33),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.82, 0.0, 0.0),
		},
		"cabeca": Vector3(0.04, 0.00, 0.00),
	},
	GESTO_APONTA: {
		"nome": "gesto_aponta", "duracao": 1.4,
		# Aponta para a frente: 'voce', 'ali'.
		"alvos": {D: Vector3(0.28, 1.38, -0.56)},
		"cotovelos": {D: Vector3(0.26, 1.31, -0.34)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(-0.04, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(2.29, 1.74, 1.71),
			Corpo.Osso.ANTEBRACO_D: Vector3(0.43, 0.0, 0.0),
		},
		"cabeca": Vector3(-0.02, 0.00, 0.00),
	},
	GESTO_ACENO: {
		"nome": "gesto_aceno", "duracao": 1.6,
		# Acena com a mao no alto.
		"alvos": {D: Vector3(0.36, 1.74, -0.12)},
		"cotovelos": {D: Vector3(0.40, 1.36, -0.05)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(0.00, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(2.03, 0.04, 0.45),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.47, 0.0, 0.0),
		},
		"cabeca": Vector3(-0.04, 0.00, 0.06),
	},
	GESTO_NEGA: {
		"nome": "gesto_nega", "duracao": 1.2,
		# So a cabeca, de um lado para o outro.
		"ossos": {
			Corpo.Osso.TORSO: Vector3(0.00, 0.0, 0.0),
		},
		"cabeca": Vector3(0.00, 0.00, 0.00),
	},
	GESTO_CONCORDA: {
		"nome": "gesto_concorda", "duracao": 1.2,
		# So a cabeca, para baixo e para cima.
		"ossos": {
			Corpo.Osso.TORSO: Vector3(0.00, 0.0, 0.0),
		},
		"cabeca": Vector3(0.00, 0.00, 0.00),
	},
	REACAO_PROTEGE: {
		"nome": "reacao_protege", "duracao": 1.8,
		# Protege o rosto com os antebracos.
		"alvos": {D: Vector3(0.08, 1.62, -0.26), E: Vector3(-0.08, 1.60, -0.26)},
		"cotovelos": {D: Vector3(0.22, 1.38, -0.20), E: Vector3(-0.22, 1.38, -0.20)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(-0.10, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(1.03, 1.88, 1.86),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.67, 0.0, 0.0),
			Corpo.Osso.BRACO_E: Vector3(1.04, -1.75, -1.71),
			Corpo.Osso.ANTEBRACO_E: Vector3(1.74, 0.0, 0.0),
		},
		"cabeca": Vector3(0.25, 0.00, 0.00),
	},
	REACAO_MAOS_ALTO: {
		"nome": "reacao_maos_alto", "duracao": 2.5,
		# Maos para o alto: rendido, a blitz.
		"alvos": {D: Vector3(0.28, 1.92, -0.06), E: Vector3(-0.28, 1.92, -0.06)},
		"cotovelos": {D: Vector3(0.36, 1.62, -0.03), E: Vector3(-0.36, 1.62, -0.03)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(0.02, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(2.75, -0.74, -0.04),
			Corpo.Osso.ANTEBRACO_D: Vector3(0.46, 0.0, 0.0),
			Corpo.Osso.BRACO_E: Vector3(2.75, 0.74, 0.04),
			Corpo.Osso.ANTEBRACO_E: Vector3(0.46, 0.0, 0.0),
		},
		"cabeca": Vector3(-0.04, 0.00, 0.00),
	},
	REACAO_XINGA: {
		"nome": "reacao_xinga", "duracao": 1.6,
		# Punho no alto, sacudindo: xingando.
		"alvos": {D: Vector3(0.24, 1.62, -0.32)},
		"cotovelos": {D: Vector3(0.30, 1.32, -0.10)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(-0.04, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(1.51, -0.21, -0.21),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.55, 0.0, 0.0),
		},
		"cabeca": Vector3(-0.06, 0.00, 0.00),
	},
	# --- gestos de dor (depois do tombo) ---
	REACAO_DOR_CABECA: {
		"nome": "reacao_dor_cabeca", "duracao": 2.6,
		# Mao na cabeca, do lado, cabeca pendendo: bateu a cabeca no chao.
		"alvos": {D: Vector3(0.12, 1.63, -0.06)},
		"cotovelos": {D: Vector3(0.34, 1.46, -0.10)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(-0.06, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(0.74, 1.88, 2.75),
			Corpo.Osso.ANTEBRACO_D: Vector3(2.03, 0.0, 0.0),
		},
		"cabeca": Vector3(0.22, 0.00, -0.14),
	},
	REACAO_DOR_COSTAS: {
		"nome": "reacao_dor_costas", "duracao": 2.8,
		# Mao na lombar, tronco curvado: caiu de costas.
		"alvos": {D: Vector3(0.07, 1.02, 0.16)},
		"cotovelos": {D: Vector3(0.30, 1.14, 0.14)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(-0.26, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(-2.48, -2.12, 2.43),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.27, 0.0, 0.0),
		},
		"cabeca": Vector3(0.16, 0.00, 0.00),
	},
	REACAO_DOR_BARRIGA: {
		"nome": "reacao_dor_barriga", "duracao": 2.6,
		# As duas maos na barriga, curvado para a frente: levou no tronco.
		"alvos": {D: Vector3(0.08, 1.10, -0.17), E: Vector3(-0.10, 1.16, -0.16)},
		"cotovelos": {D: Vector3(0.24, 1.06, -0.04), E: Vector3(-0.24, 1.10, -0.04)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(-0.22, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(-0.31, 0.94, 0.11),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.98, 0.0, 0.0),
			Corpo.Osso.BRACO_E: Vector3(-0.46, -1.15, -0.56),
			Corpo.Osso.ANTEBRACO_E: Vector3(2.24, 0.0, 0.0),
		},
		"cabeca": Vector3(0.26, 0.00, 0.00),
	},
	REACAO_DOR_BRACO: {
		"nome": "reacao_dor_braco", "duracao": 2.6,
		# Segura o antebraco direito com a mao esquerda, olhando para ele.
		"alvos": {D: Vector3(0.16, 1.02, -0.22), E: Vector3(0.19, 1.07, -0.16)},
		"cotovelos": {D: Vector3(0.25, 1.10, -0.02), E: Vector3(-0.18, 1.08, -0.08)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(-0.06, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(-0.43, 1.08, 0.60),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.55, 0.0, 0.0),
			Corpo.Osso.BRACO_E: Vector3(0.62, -1.64, -0.37),
			Corpo.Osso.ANTEBRACO_E: Vector3(0.64, 0.0, 0.0),
		},
		"cabeca": Vector3(0.30, 0.00, 0.08),
	},
	REACAO_MAO_NA_CABECA: {
		"nome": "reacao_mao_na_cabeca", "duracao": 7.0,
		# Maos na cabeca, dedos cruzados na nuca, cotovelos abertos: a revista da blitz.
		"alvos": {D: Vector3(0.06, 1.73, 0.04), E: Vector3(-0.06, 1.73, 0.04)},
		"cotovelos": {D: Vector3(0.36, 1.64, -0.02), E: Vector3(-0.36, 1.64, -0.02)},
		"ossos": {
			Corpo.Osso.TORSO: Vector3(0.00, 0.0, 0.0),
			Corpo.Osso.BRACO_D: Vector3(2.65, -2.12, 0.44),
			Corpo.Osso.ANTEBRACO_D: Vector3(1.49, 0.0, 0.0),
			Corpo.Osso.BRACO_E: Vector3(2.65, 2.12, -0.44),
			Corpo.Osso.ANTEBRACO_E: Vector3(1.49, 0.0, 0.0),
		},
		"cabeca": Vector3(0.12, 0.00, 0.00),
	},
}


static func nome(tipo: int) -> String:
	return String(POSES.get(tipo, {}).get("nome", "nenhuma"))


static func duracao(tipo: int) -> float:
	return float(POSES.get(tipo, {}).get("duracao", 0.0))


## Qual reacao cada campo da criacao dispara.
static func do_campo(chave: StringName) -> int:
	match chave:
		&"rosto":
			return ROSTO
		&"pele":
			return PELE
		&"barba":
			return BARBA
		&"cabelo", &"cabelo_cor", &"penteado":
			return CABELO
		&"camisa", &"camisa_cor", &"camisa_estilo":
			return ROUPA
		&"casaco_estilo", &"casaco_cel", &"casaco_cor":
			return AGASALHO
		&"calca", &"calca_cor", &"calca_estilo":
			return PERNAS
		&"sapato_estilo", &"sapato_cor":
			return PES
		&"chapeu_tipo", &"chapeu_cor":
			return CHAPEU
		&"oculos":
			return OCULOS
		&"altura", &"gordura", &"ombro":
			return CORPO
	return NENHUMA


## O envelope: sobe em um quarto, segura, desce no ultimo quarto. Suave nas
## pontas porque o passo ja e travado — duro em cima de duro vira tranco.
static func envelope(p: float) -> float:
	if p <= 0.0 or p >= 1.0:
		return 0.0
	if p < 0.25:
		return smoothstep(0.0, 0.25, p)
	if p > 0.75:
		return 1.0 - smoothstep(0.75, 1.0, p)
	return 1.0


## Quanto do "meio" da reacao ja passou, de 0 a 1 so na janela cheia. E o
## relogio do gesto secundario: esfregar o cabelo, puxar a barra duas vezes.
static func _meio(p: float) -> float:
	return clampf((p - 0.25) / 0.5, 0.0, 1.0)


## O gesto secundario de cada reacao, somado ao angulo do osso. Sem ele a pose
## chega e congela, e congelada ela le como foto de catalogo.
static func _vivo(tipo: int, osso: int, t: float, meio: float) -> Vector3:
	var janela := sin(meio * PI)
	match tipo:
		ROSTO:
			if osso == Corpo.Osso.ANTEBRACO_D:
				return Vector3(sin(t * 5.2) * 0.05 * janela, 0.0, 0.0)
		CABELO:
			if osso == Corpo.Osso.ANTEBRACO_D:
				return Vector3(sin(t * 11.0) * 0.16 * janela, 0.0, 0.0)
		ROUPA:
			if osso == Corpo.Osso.TORSO:
				return Vector3(0.0, sin(t * 4.0) * 0.22 * janela, 0.0)
			if osso == Corpo.Osso.ANTEBRACO_D or osso == Corpo.Osso.ANTEBRACO_E:
				return Vector3(-absf(sin(t * 6.0)) * 0.16 * janela, 0.0, 0.0)
		AGASALHO:
			if osso == Corpo.Osso.ANTEBRACO_D or osso == Corpo.Osso.ANTEBRACO_E:
				return Vector3(absf(sin(t * 7.0)) * 0.14 * janela, 0.0, 0.0)
		PERNAS:
			if osso == Corpo.Osso.ANTEBRACO_D or osso == Corpo.Osso.ANTEBRACO_E:
				return Vector3(sin(t * 7.5) * 0.12 * janela, 0.0, 0.0)
		PES:
			if osso == Corpo.Osso.COXA_D:
				return Vector3(0.0, sin(t * 6.0) * 0.28 * janela, 0.0)
		CHAPEU:
			if osso == Corpo.Osso.ANTEBRACO_D:
				return Vector3(sin(t * 8.0) * 0.07 * janela, 0.0, 0.0)
		BARBA:
			if osso == Corpo.Osso.ANTEBRACO_D:
				return Vector3(sin(t * 6.5) * 0.14 * janela, 0.0, 0.0)
		CORPO:
			if osso == Corpo.Osso.ANTEBRACO_D or osso == Corpo.Osso.ANTEBRACO_E:
				return Vector3(absf(sin(t * 5.0)) * 0.22 * janela, 0.0, 0.0)
		PELE:
			if osso == Corpo.Osso.BRACO_D:
				return Vector3(0.0, sin(t * 3.4) * 0.45 * janela, 0.0)
		APROVADO:
			# O polegar balanca duas vezes: "isso ai".
			if osso == Corpo.Osso.ANTEBRACO_D:
				return Vector3(-absf(sin(t * 7.0)) * 0.14 * janela, 0.0, 0.0)
		OCIO_NUCA:
			if osso == Corpo.Osso.ANTEBRACO_D:
				return Vector3(sin(t * 12.0) * 0.12 * janela, 0.0, 0.0)
		OCIO_CELULAR:
			# O polegar rolando a tela: o antebraco treme de leve.
			if osso == Corpo.Osso.ANTEBRACO_D:
				return Vector3(sin(t * 9.0) * 0.04 * janela, 0.0, 0.0)
		OCIO_BENZE:
			# Testa, peito, ombro, ombro: o braco desce e cruza.
			if osso == Corpo.Osso.BRACO_D:
				return Vector3(-0.55 * meio, sin(meio * TAU) * 0.35, 0.0) * janela
		OCIO_ESFREGA:
			if osso == Corpo.Osso.ANTEBRACO_D:
				return Vector3(0.0, sin(t * 10.0) * 0.22 * janela, 0.0)
			if osso == Corpo.Osso.ANTEBRACO_E:
				return Vector3(0.0, -sin(t * 10.0) * 0.22 * janela, 0.0)
		GESTO_EXPLICA:
			if osso == Corpo.Osso.ANTEBRACO_D:
				return Vector3(sin(t * 6.0) * 0.14 * janela, 0.0, 0.0)
		GESTO_ABRE:
			if osso == Corpo.Osso.ANTEBRACO_D or osso == Corpo.Osso.ANTEBRACO_E:
				return Vector3(-absf(sin(t * 4.0)) * 0.12 * janela, 0.0, 0.0)
		GESTO_APONTA:
			# Duas batidas do dedo na direcao do alvo.
			if osso == Corpo.Osso.ANTEBRACO_D:
				return Vector3(absf(sin(t * 8.0)) * 0.10 * janela, 0.0, 0.0)
		GESTO_ACENO:
			if osso == Corpo.Osso.BRACO_D:
				return Vector3(0.0, sin(t * 11.0) * 0.30 * janela, 0.0)
		REACAO_XINGA:
			if osso == Corpo.Osso.ANTEBRACO_D:
				return Vector3(sin(t * 13.0) * 0.20 * janela, 0.0, 0.0)
		REACAO_PROTEGE:
			if osso == Corpo.Osso.TORSO:
				return Vector3(-0.08 * janela, 0.0, 0.0)
		REACAO_DOR_CABECA:
			# Esfrega o lugar da pancada.
			if osso == Corpo.Osso.ANTEBRACO_D:
				return Vector3(sin(t * 7.0) * 0.12 * janela, 0.0, 0.0)
		REACAO_DOR_COSTAS:
			# Tenta endireitar e volta a curvar.
			if osso == Corpo.Osso.TORSO:
				return Vector3(absf(sin(t * 1.8)) * 0.12 * janela, 0.0, 0.0)
		REACAO_DOR_BARRIGA:
			# Respira curto, dobrado.
			if osso == Corpo.Osso.TORSO:
				return Vector3(-absf(sin(t * 3.2)) * 0.07 * janela, 0.0, 0.0)
		REACAO_DOR_BRACO:
			if osso == Corpo.Osso.ANTEBRACO_E:
				return Vector3(sin(t * 5.0) * 0.08 * janela, 0.0, 0.0)
	return Vector3.ZERO


## Aplica a reacao por cima da pose ja montada. Devolve o que somar na cabeca:
## inclinacao, giro e tombo — quem escreve a cabeca e o Corpo, por ultimo.
##
## `vivo` falso tira o gesto secundario: e como o teste confere a pose-base, que
## e o que o resolvedor garante. O gesto e somado por cima de proposito.
static func aplicar(corpo: Corpo, tipo: int, t: float, vivo: bool = true) -> Vector3:
	var pose: Dictionary = POSES.get(tipo, {})
	if pose.is_empty():
		return Vector3.ZERO
	var sk := corpo.esqueleto()
	var dur := float(pose["duracao"])
	var tq := floorf(t * PASSOS_POR_SEGUNDO) / PASSOS_POR_SEGUNDO
	var p := tq / dur
	var e := envelope(p)
	if e <= 0.0:
		return Vector3.ZERO
	var meio := _meio(p)
	var ossos: Dictionary = pose["ossos"]
	for osso: int in ossos:
		var alvo: Vector3 = ossos[osso]
		if vivo:
			alvo += _vivo(tipo, osso, tq, meio)
		var q_alvo := Basis.from_euler(alvo).get_rotation_quaternion()
		var q_agora := sk.get_bone_pose_rotation(osso)
		sk.set_bone_pose_rotation(osso, q_agora.slerp(q_alvo, e))
	if pose.has("quadril"):
		var desvio: Vector3 = pose["quadril"]
		var rest := sk.get_bone_rest(Corpo.Osso.QUADRIL).origin
		var agora := sk.get_bone_pose_position(Corpo.Osso.QUADRIL)
		sk.set_bone_pose_position(Corpo.Osso.QUADRIL,
			agora.lerp(rest + Vector3(desvio.x, corpo._y(desvio.y), desvio.z), e))
	var cabeca: Vector3 = pose["cabeca"]
	var aceno := Vector3.ZERO
	if tipo == ROSTO or tipo == BARBA:
		aceno.x = sin(tq * 3.1) * 0.05 * sin(meio * PI)
	elif tipo == OCIO_OLHAR:
		# Um lado, o outro, e de volta para a frente.
		aceno.y = sin(meio * TAU) * 0.55
	elif tipo == APROVADO:
		aceno.x = -absf(sin(tq * 7.0)) * 0.06 * sin(meio * PI)
	elif tipo == GESTO_NEGA:
		aceno.y = sin(tq * 12.0) * 0.24 * sin(meio * PI)
	elif tipo == GESTO_CONCORDA:
		aceno.x = absf(sin(tq * 7.5)) * 0.18 * sin(meio * PI)
	elif tipo == REACAO_XINGA:
		aceno.x = -absf(sin(tq * 13.0)) * 0.05 * sin(meio * PI)
	return cabeca * e + aceno
