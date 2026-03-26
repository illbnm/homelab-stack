/**
 * Node-RED 设置文件
 * HomeLab Stack — Home Automation
 */

// 模块缓存路径
process.env.NODE_RED_HOME = '/data'

const path = require('path')

module.exports = {
    // Node-RED 设置
    uiPort: process.env.PORT || 1880,

    // 允许以 root 用户运行
    runtimeState: {
        enabled: true,
        ui: {
            // 禁用某些功能以提高安全性
            diagnostics: {
                enabled: true,
                displayErrorCodes: false
            }
        }
    },

    //Flows 配置
    flows: {
        // 流动文件（使用持久化存储时）
        stateType: 'filesystem',
        // 安全启动模式（生产环境建议开启）
        safeMode: false,
    },

    // 编辑器配置
    editorTheme: {
        projects: {
            enabled: false, // 生产环境建议关闭
        },
        view: {
            hideIntro: false,
        }
    },

    // 日志配置
    logging: {
        console: {
            level: 'info',
            metrics: false,
            audit: false
        }
    },

    // 上下文存储（持久化）
    contextStorage: {
        default: {
            module: 'localfilesystem',
            config: {
                dir: '/data/context',
                flushInterval: 30
            }
        },
        memory: {
            module: 'memory'
        }
    },

    // 认证（建议通过反向代理保护）
    apiAuth: {
        type: 'credentials',
        users: [
            // 如果需要本地认证，在这里配置
            // { username: 'admin', password: 'xxx', permissions: '*' }
        ]
    },

    // 限流
    rateLimit: {
        maximum: 1000,
        windowMs: 60000
    },

    // 外部节点路径
    nodesDir: '/data/nodes',
    libPath: '/data/lib',

    // MQTT Broker 配置
    mqttReconnectTime: 5000,
    mqttSocketTimeout: 60,

    // WebSocket 超时
    webSocketNodeAddr: '/homeautomationws',
    webSocketTimeout: 1209600,

    // 编辑器设置
    editorTheme: {
        theme: 'theme-light',
        codeEditor: {
            lib: 'monaco',
            options: {
                theme: 'vs'
            }
        }
    },

    // 国际化
    lang: 'zh-CN',

    // TLS 配置（可选）
    https: undefined,
}
