/**
 * Node-RED Settings
 */
module.exports = {
    // Node-RED 路由
    httpAdminRoot: "/",
    httpNodeRoot: "/",
    
    // 用户安全
    // adminAuth: {
    //     type: "credentials",
    //     users: [{
    //         username: "admin",
    //         password: "$2a$08$...hashed password..."
    //     }]
    // },
    
    // 禁用编辑器（生产环境）
    // disableEditor: false,
    
    // 日志级别
    logging: {
        console: {
            level: "info",
            metrics: false,
            audit: false
        }
    },
    
    // MQTT 连接节点
    mqttReconnectTime: 15000,
    
    // 调试输出
    debugMaxLength: 1000,
    
    // 流程配置
    flowFile: 'flows.json',
    flowFilePretty: true,
    
    // 凭证加密
    credentialsSecret: process.env.NODE_RED_CREDENTIAL_SECRET || "change-me-in-production",
    
    // 上下文存储
    contextStorage: {
        default: {
            module: "localfilesystem"
        }
    },
    
    // 节点配置
    nodesDir: './nodes',
    
    // 功能开关
    functionGlobalContext: {
        // os: require('os'),
        // 提供 MQTT 客户端
    }
};
