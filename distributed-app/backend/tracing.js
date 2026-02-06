// =============================================================================
// JAEGER TRACING CONFIGURATION - BACKEND SERVICE
// =============================================================================
// Configuração de instrumentação com Jaeger Client Library nativo
// Aula 05 - PosTech DevOps e Arquitetura Cloud - Monitoramento OpenSource
// 
// OBJETIVO: Configurar tracing distribuído para rastrear operações do backend
// incluindo queries no banco, cache Redis, e mensageria RabbitMQ
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
  // Diferente do frontend para separar traces por serviço
  serviceName: process.env.JAEGER_SERVICE_NAME || 'backend-service',
  
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
    // Mesmo agent usado pelo frontend - centraliza coleta
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
    // Backend pode ter mais spans que frontend (DB, cache, etc)
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
    'backend-service.version': '1.0.0',
    
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
  console.log('🔍 Jaeger tracing initialized for backend-service');
  console.log(`📡 Agent: ${config.reporter.agentHost}:${config.reporter.agentPort}`);
  console.log(`🎯 Sampling: ${config.sampler.type} (${config.sampler.param})`);
  
  // EXPLICAÇÃO DO FLUXO NO BACKEND:
  // 1. Frontend envia requisição com contexto de trace nos headers
  // 2. Backend extrai contexto e cria span filho do frontend
  // 3. Backend cria spans para operações internas:
  //    - redis_get/redis_set (cache)
  //    - postgres_query/postgres_insert (database)
  //    - rabbitmq_publish (messaging)
  // 4. Todos os spans são enviados via UDP para Jaeger Agent
  // 5. Agent faz batching e envia para Collector
  // 6. Jaeger UI mostra trace completo: frontend → backend → DB/cache
  
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
    // Importante no backend que pode ter muitos spans em buffer
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
// COMO USAR ESTE TRACER NO BACKEND:
// =============================================================================
// 
// 1. EXTRAIR CONTEXTO DO FRONTEND (requisição recebida):
//    const parentContext = tracer.extract(
//      opentracing.FORMAT_HTTP_HEADERS, 
//      req.headers
//    );
//    const span = tracer.startSpan('GET /api/users', {
//      childOf: parentContext  // Conecta com span do frontend
//    });
// 
// 2. CRIAR SPAN PARA OPERAÇÃO DE CACHE:
//    const cacheSpan = tracer.startSpan('redis_get', {
//      childOf: parentSpan,
//      tags: {
//        'db.type': 'redis',
//        'db.operation': 'get',
//        'cache.key': 'users_list'
//      }
//    });
//    // ... operação de cache ...
//    cacheSpan.setTag('cache.hit', true);
//    cacheSpan.finish();
// 
// 3. CRIAR SPAN PARA QUERY NO BANCO:
//    const dbSpan = tracer.startSpan('postgres_query', {
//      childOf: parentSpan,
//      tags: {
//        'db.type': 'postgresql',
//        'db.operation': 'select',
//        'db.table': 'users',
//        'db.statement': 'SELECT * FROM users'
//      }
//    });
//    // ... query no banco ...
//    dbSpan.setTag('db.rows_returned', result.rows.length);
//    dbSpan.log({ event: 'query_completed', rows: result.rows.length });
//    dbSpan.finish();
// 
// 4. CRIAR SPAN PARA MENSAGERIA:
//    const mqSpan = tracer.startSpan('rabbitmq_publish', {
//      childOf: parentSpan,
//      tags: {
//        'messaging.system': 'rabbitmq',
//        'messaging.destination': 'order_processing',
//        'messaging.operation': 'publish'
//      }
//    });
//    // ... publicar mensagem ...
//    mqSpan.setTag('messaging.success', true);
//    mqSpan.finish();
// 
// 5. ADICIONAR LOGS DE EVENTOS:
//    span.log({ event: 'cache_miss', key: 'users_list' });
//    span.log({ event: 'database_query_start', table: 'users' });
//    span.log({ event: 'validation_failed', reason: 'invalid_email' });
// 
// 6. MARCAR ERROS:
//    span.setTag(opentracing.Tags.ERROR, true);
//    span.log({
//      event: 'error',
//      'error.kind': error.name,
//      message: error.message,
//      stack: error.stack
//    });
// 
// 7. SEMPRE FINALIZAR SPANS:
//    span.finish();  // Envia span para o Jaeger Agent
// 
// =============================================================================
// EXEMPLO DE TRACE COMPLETO NO BACKEND:
// =============================================================================
// 
// GET /api/users (500ms total)
//   ├─ redis_get (10ms) → cache miss
//   ├─ postgres_query (400ms) → SELECT * FROM users
//   └─ redis_set (20ms) → armazena no cache
// 
// POST /api/orders (800ms total)
//   ├─ validation (50ms) → valida dados
//   ├─ postgres_insert (400ms) → INSERT INTO orders
//   ├─ rabbitmq_publish (200ms) → publica mensagem
//   └─ redis_delete (20ms) → invalida cache
// 
// =============================================================================
// TAGS RECOMENDADAS PARA BACKEND:
// =============================================================================
// 
// DATABASE:
//   - db.type: 'postgresql', 'mysql', 'mongodb'
//   - db.operation: 'select', 'insert', 'update', 'delete'
//   - db.table: nome da tabela
//   - db.statement: query SQL (cuidado com dados sensíveis!)
//   - db.rows_returned: número de linhas retornadas
//   - db.rows_affected: número de linhas afetadas
// 
// CACHE:
//   - db.type: 'redis', 'memcached'
//   - db.operation: 'get', 'set', 'delete'
//   - cache.key: chave do cache
//   - cache.hit: true/false
//   - cache.ttl: tempo de vida em segundos
// 
// MESSAGING:
//   - messaging.system: 'rabbitmq', 'kafka', 'sqs'
//   - messaging.destination: nome da fila/tópico
//   - messaging.operation: 'publish', 'consume'
//   - messaging.message_id: ID da mensagem
// 
// HTTP (chamadas externas):
//   - http.method: 'GET', 'POST', etc
//   - http.url: URL completa
//   - http.status_code: código de resposta
// 
// BUSINESS LOGIC:
//   - user.id: ID do usuário
//   - order.id: ID do pedido
//   - product.count: quantidade de produtos
//   - validation.success: true/false
// 
// =============================================================================
// VARIÁVEIS DE AMBIENTE SUPORTADAS:
// =============================================================================
// 
// JAEGER_SERVICE_NAME=backend-service
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
// TROUBLESHOOTING:
// =============================================================================
// 
// 1. Traces não aparecem no Jaeger:
//    - Verificar se Jaeger Agent está rodando
//    - Verificar conectividade: telnet jaeger-agent 6832
//    - Verificar logs: docker-compose logs jaeger-agent
//    - Verificar sampling: param deve ser > 0
// 
// 2. Traces aparecem mas sem conexão com frontend:
//    - Verificar se contexto está sendo extraído dos headers
//    - Verificar se frontend está injetando contexto
//    - Verificar logs: procurar por trace_id nos dois serviços
// 
// 3. Performance degradada:
//    - Reduzir sampling (probabilistic 0.1 = 10%)
//    - Aumentar flushIntervalMs (5000ms)
//    - Verificar se há muitos spans sendo criados
// 
// 4. Spans não aparecem completos:
//    - Verificar se span.finish() está sendo chamado
//    - Verificar se há erros antes do finish()
//    - Usar try/finally para garantir finish()
// 
// =============================================================================
