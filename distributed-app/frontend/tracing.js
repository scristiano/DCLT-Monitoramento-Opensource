// =============================================================================
// JAEGER TRACING CONFIGURATION - FRONTEND SERVICE
// =============================================================================
// Configuração de instrumentação com Jaeger Client Library nativo
// Aula 05 - PosTech DevOps e Arquitetura Cloud - Monitoramento OpenSource
// 
// OBJETIVO: Configurar tracing distribuído para rastrear requisições entre
// frontend e backend, permitindo visualização completa do fluxo de dados
// =============================================================================

// Importar bibliotecas necessárias
const jaeger = require('jaeger-client');      // Cliente nativo Jaeger
const opentracing = require('opentracing');   // API padrão OpenTracing

// =============================================================================
// CONFIGURAÇÃO DO JAEGER CLIENT
// =============================================================================
// Esta configuração define como os traces serão coletados e enviados
const config = {
  // Nome do serviço que aparecerá no Jaeger UI
  // Usado para identificar de qual serviço os traces estão vindo
  serviceName: process.env.JAEGER_SERVICE_NAME || 'frontend-service',
  
  // SAMPLER: Define quais requisições serão rastreadas
  // =============================================================================
  sampler: {
    // Tipos disponíveis:
    // - 'const': Sampling constante (0 = nenhum, 1 = todos)
    // - 'probabilistic': Sampling probabilístico (0.0 a 1.0)
    // - 'ratelimiting': Limita número de traces por segundo
    // - 'remote': Busca estratégia do Jaeger Agent
    type: process.env.JAEGER_SAMPLER_TYPE || 'const',
    
    // Parâmetro do sampler:
    // - const: 1 = 100% das requisições, 0 = 0%
    // - probabilistic: 0.5 = 50% das requisições
    // - ratelimiting: número máximo de traces/segundo
    param: parseFloat(process.env.JAEGER_SAMPLER_PARAM || '1'),
  },
  
  // REPORTER: Define como e para onde os traces serão enviados
  // =============================================================================
  reporter: {
    // Host do Jaeger Agent (coleta traces localmente)
    // O agent faz batching e envia para o Collector na Instância 1
    agentHost: process.env.JAEGER_AGENT_HOST || 'localhost',
    
    // Porta UDP do Jaeger Agent
    // 6831 = Thrift compact protocol
    // 6832 = Thrift binary protocol (mais eficiente)
    agentPort: parseInt(process.env.JAEGER_AGENT_PORT || '6832'),
    
    // Log de spans no console (útil para debug)
    // true = mostra spans sendo enviados
    // false = silencioso
    logSpans: true,
    
    // Intervalo de flush (envio) dos spans para o agent
    // 2000ms = envia spans a cada 2 segundos
    // Menor valor = mais tempo real, maior overhead
    // Maior valor = menos overhead, menos tempo real
    flushIntervalMs: 2000,
  },
};

// =============================================================================
// OPÇÕES ADICIONAIS DO TRACER
// =============================================================================
// Configurações extras para enriquecer os traces com metadados
const options = {
  // TAGS GLOBAIS: Adicionadas a todos os spans deste serviço
  // Útil para filtrar traces no Jaeger UI por versão, ambiente, etc.
  tags: {
    // Versão do serviço (útil para comparar performance entre versões)
    'frontend-service.version': '1.0.0',
    
    // Ambiente de deployment (development, staging, production)
    // Permite filtrar traces por ambiente no Jaeger
    'deployment.environment': process.env.NODE_ENV || 'development',
  },
  
  // LOGGER CUSTOMIZADO: Define como o tracer loga informações
  // Útil para debug e troubleshooting
  logger: {
    // Logs informativos (inicialização, configuração)
    info: (msg) => console.log('JAEGER INFO:', msg),
    
    // Logs de erro (falhas de conexão, problemas de envio)
    error: (msg) => console.error('JAEGER ERROR:', msg),
  },
};

// =============================================================================
// INICIALIZAÇÃO DO TRACER
// =============================================================================
// Cria e configura o tracer com tratamento de erro robusto
let tracer;
try {
  // Inicializar tracer com configurações definidas
  // Este tracer será usado para criar spans em toda a aplicação
  tracer = jaeger.initTracer(config, options);
  
  // Definir como tracer global do OpenTracing
  // Permite usar opentracing.globalTracer() em qualquer lugar do código
  // Facilita a instrumentação sem passar o tracer como parâmetro
  opentracing.initGlobalTracer(tracer);
  
  // Logs de confirmação de inicialização
  console.log('🔍 Jaeger tracing initialized for frontend-service');
  console.log(`📡 Agent: ${config.reporter.agentHost}:${config.reporter.agentPort}`);
  console.log(`🎯 Sampling: ${config.sampler.type} (${config.sampler.param})`);
  
  // EXPLICAÇÃO DO FLUXO:
  // 1. Aplicação cria spans usando este tracer
  // 2. Spans são enviados via UDP para Jaeger Agent (porta 6832)
  // 3. Agent faz batching e envia via gRPC para Collector (porta 14250)
  // 4. Collector armazena no backend (Cassandra/Elasticsearch)
  // 5. Jaeger UI consulta e exibe os traces
  
} catch (error) {
  // FALLBACK: Se falhar ao inicializar, continua sem tracing
  // Isso evita que a aplicação quebre se o Jaeger não estiver disponível
  console.error('❌ Failed to initialize Jaeger tracer:', error.message);
  console.log('🔄 Continuing without tracing...');
  
  // Criar um tracer noop (no-operation) como fallback
  // Este tracer não faz nada, mas mantém a API compatível
  // A aplicação continua funcionando normalmente, apenas sem traces
  tracer = new opentracing.Tracer();
  opentracing.initGlobalTracer(tracer);
}

// =============================================================================
// GRACEFUL SHUTDOWN
// =============================================================================
// Garante que todos os spans sejam enviados antes de encerrar a aplicação
process.on('SIGTERM', () => {
  // Verificar se tracer tem método close (tracer real, não noop)
  if (tracer && typeof tracer.close === 'function') {
    // Fechar tracer de forma graciosa
    // Isso força o flush de todos os spans pendentes
    tracer.close(() => {
      console.log('🔍 Jaeger tracer closed');
      process.exit(0);
    });
  } else {
    // Se for tracer noop, apenas encerra
    process.exit(0);
  }
});

// =============================================================================
// EXPORTAÇÃO
// =============================================================================
// Exportar tracer para uso em toda a aplicação
// Uso: const tracer = require('./tracing');
//      const span = tracer.startSpan('operation_name');
module.exports = tracer;

// =============================================================================
// COMO USAR ESTE TRACER NA APLICAÇÃO:
// =============================================================================
// 
// 1. CRIAR SPAN RAIZ (requisição HTTP):
//    const span = tracer.startSpan('GET /api/users', {
//      tags: {
//        'http.method': 'GET',
//        'http.url': '/api/users'
//      }
//    });
// 
// 2. CRIAR SPAN FILHO (operação interna):
//    const childSpan = tracer.startSpan('database_query', {
//      childOf: parentSpan,
//      tags: {
//        'db.type': 'postgresql',
//        'db.operation': 'select'
//      }
//    });
// 
// 3. ADICIONAR TAGS (metadados):
//    span.setTag('user.id', 123);
//    span.setTag('cache.hit', true);
// 
// 4. ADICIONAR LOGS (eventos):
//    span.log({ event: 'cache_miss', key: 'users_list' });
//    span.log({ event: 'error', message: error.message });
// 
// 5. PROPAGAR CONTEXTO (entre serviços):
//    const headers = {};
//    tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, headers);
//    axios.get(url, { headers });
// 
// 6. EXTRAIR CONTEXTO (receber de outro serviço):
//    const parentContext = tracer.extract(
//      opentracing.FORMAT_HTTP_HEADERS, 
//      req.headers
//    );
//    const span = tracer.startSpan('operation', { childOf: parentContext });
// 
// 7. FINALIZAR SPAN:
//    span.finish();  // SEMPRE finalizar para enviar ao Jaeger
// 
// =============================================================================
// VARIÁVEIS DE AMBIENTE SUPORTADAS:
// =============================================================================
// 
// JAEGER_SERVICE_NAME=frontend-service
//   Nome do serviço no Jaeger UI
// 
// JAEGER_AGENT_HOST=jaeger-agent
//   Host do Jaeger Agent (container name ou IP)
// 
// JAEGER_AGENT_PORT=6832
//   Porta UDP do Jaeger Agent (6831 ou 6832)
// 
// JAEGER_SAMPLER_TYPE=const
//   Tipo de sampling (const, probabilistic, ratelimiting, remote)
// 
// JAEGER_SAMPLER_PARAM=1
//   Parâmetro do sampler (0-1 para const/probabilistic, N para ratelimiting)
// 
// NODE_ENV=production
//   Ambiente de deployment (usado nas tags globais)
// 
// =============================================================================