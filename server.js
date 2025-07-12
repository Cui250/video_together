const WebSocket = require('ws');

// 创建WebSocket服务器，监听8080端口
const wss = new WebSocket.Server({ port: 8080 });

// 存储所有房间信息
const rooms = new Map();
// 添加消息类型白名单
const validMessageTypes = new Set([
    'create_room',
    'join_room',
    'sync_playback',
    'leave_room',
    'ping',
    'handshake',
    'chat_message' // 新增聊天消息类型
]);

console.log('WebSocket服务器已启动，监听端口 8080...');

wss.on('connection', (ws) => {
    console.log('新的客户端连接');
    // 初始化必要属性
    ws.currentRoom = null;
    ws.userId = `user_${Math.random().toString(36).substr(2, 9)}`;

    let currentRoom = null;
    let userId = `user_${Math.random().toString(36).substr(2, 9)}`;

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);

            if (!validMessageTypes.has(data.type)) {
                throw new Error(`无效消息类型: ${data.type}`);
            }

            // 添加ping-pong处理
            if (data.type === 'ping') {
                ws.send(JSON.stringify({
                    type: 'pong',
                    timestamp: Date.now()
                }));
                return;
            }

            switch (data.type) {
                case 'handshake':
                    handleHandshake(ws, data, userId);
                    break;

                case 'create_room':
                    handleCreateRoom(ws, data, userId);
                    break;

                case 'join_room':
                    handleJoinRoom(ws, data, userId);
                    break;

                case 'sync_playback':
                    handleSyncPlayback(data);
                    break;

                case 'leave_room':
                    handleLeaveRoom(data, userId);
                    break;
                case 'chat_message':
                    handleChatMessage(data);
                    break;

                case 'video_share_request':
                    handleVideoShareRequest(ws, data);
                    break;

                case 'video_chunk':
                    forwardVideoChunk(data);
                    break;

                case 'video_transfer_complete':
                    forwardVideoTransferComplete(data);
                    break;

                case 'sync_request':
                    handleSyncRequest(ws, data);
                    break;
                // 处理视频共享响应
                case 'video_share_response':
                    forwardVideoShareResponse(data);
                    break;

                default:
                    ws.send(JSON.stringify({
                        type: 'error',
                        message: '未知的消息类型'
                    }));
            }
        } catch (e) {
            console.error('消息处理错误:', e);
            ws.send(JSON.stringify({
                type: 'error',
                message: '无效的消息格式'
            }));
        }
    });

    // 在connection close事件中
    ws.on('close', () => {
        console.log('客户端断开连接');
        if (currentRoom) {
            const room = rooms.get(currentRoom);
            if (room) {
                // 清理该用户发起的所有传输
                room.activeTransfers.forEach((_, requesterId) => {
                    if (requesterId === userId) {
                        room.activeTransfers.delete(requesterId);
                    }
                });
            }
            handleDisconnect(currentRoom, userId);
        }
    });
});

function handleCreateRoom(ws, data, userId) {
    console.log('创建房间,video数据：'+data.video);
    const newRoomId = `room_${Math.random().toString(36).substr(2, 6)}`;
    rooms.set(newRoomId, {
        video: data.video,
        participants: [userId],
        playback: {
            position: 0,
            isPlaying: false
        },
        chatHistory: [], // 新增聊天历史记录
        // 新增传输状态跟踪
        activeTransfers: new Map() // key: requesterId, value: { fileSize, bytesReceived }

    });

    ws.currentRoom = newRoomId;
    ws.userId = userId;

    // 修改handleCreateRoom
    ws.send(JSON.stringify({
        type: 'room_created',
        room_id: newRoomId,
        video: data.video, // 必须添加
        participants: [userId], // 明确参与者列表
        position: 0, // 初始位置
        is_playing: false // 初始状态
    }));

    console.log(`房间 ${newRoomId} 创建成功`);
}

function handleHandshake(ws, data, userId) {
    ws.send(JSON.stringify({
        type: 'handshake_response',
        message: '握手成功',
        user_id: userId
    }));

    console.log(`用户 ${userId} 完成握手`);
}

function handleJoinRoom(ws, data, userId) {
    const roomToJoin = rooms.get(data.room_id);
    if (!roomToJoin) {
        ws.send(JSON.stringify({
            type: 'error',
            message: '房间不存在'
        }));
        return;
    }

    roomToJoin.participants.push(userId);
    ws.currentRoom = data.room_id;
    ws.userId = userId;

    ws.send(JSON.stringify({
        type: 'room_joined',
        room_id: data.room_id,
        participants: roomToJoin.participants,
        video: roomToJoin.video,
        position: roomToJoin.playback.position,
        is_playing: roomToJoin.playback.isPlaying
    }));

    // 通知其他用户有新成员加入
    broadcast(data.room_id, {
        type: 'participant_update',
        participants: roomToJoin.participants
    }, ws);

    console.log(`用户 ${userId} 加入了房间 ${data.room_id}`);
}

function handleSyncPlayback(data) {
    const roomToSync = rooms.get(data.room_id);
    if (roomToSync) {
        // 更新房间状态
        roomToSync.playback = {
            position: data.position,
            isPlaying: data.is_playing
        };

        // 找到当前客户端（用于排除）
        let currentClient;
        for (const client of wss.clients) {
            if (client.userId === data.from_user) {
                currentClient = client;
                break;
            }
        }

        // 广播给房间内其他用户
        broadcast(data.room_id, {
            type: 'sync_playback',
            position: data.position,
            is_playing: data.is_playing,
            from_user: data.from_user // 添加来源标识
        }, currentClient);

        console.log(`房间 ${data.room_id} 同步状态: 位置 ${data.position}ms, 播放 ${data.is_playing}`);
    }
}
function handleLeaveRoom(data, userId) {
    const roomToLeave = rooms.get(data.room_id);
    if (roomToLeave) {
        roomToLeave.participants = roomToLeave.participants.filter(id => id !== userId);

        if (roomToLeave.participants.length === 0) {
            rooms.delete(data.room_id);
            console.log(`房间 ${data.room_id} 已被删除（无成员）`);
        } else {
            // 通知其他用户有成员离开
            broadcast(data.room_id, {
                type: 'participant_update',
                participants: roomToLeave.participants
            });
            console.log(`用户 ${userId} 离开了房间 ${data.room_id}`);
        }
    }
}

function handleDisconnect(roomId, userId) {
    const room = rooms.get(roomId);
    if (room) {
        room.participants = room.participants.filter(id => id !== userId);

        if (room.participants.length === 0) {
            rooms.delete(roomId);
            console.log(`房间 ${roomId} 已被删除（无成员）`);
        } else {
            // 通知其他用户有成员断开连接
            broadcast(roomId, {
                type: 'participant_update',
                participants: room.participants
            });
            console.log(`用户 ${userId} 从房间 ${roomId} 断开连接`);
        }
    }
}

function broadcast(roomId, message, excludeWs = null) {
    const room = rooms.get(roomId);
    if (!room) {
        console.error(`房间 ${roomId} 不存在`);
        return;
    }

    wss.clients.forEach(client => {
        try {
            if (client.readyState === WebSocket.OPEN &&
                client !== excludeWs &&
                room.participants.includes(client.userId)) {
                client.send(JSON.stringify({
                    ...message,
                    room_id: roomId
                }));
            }
        } catch (e) {
            console.error('广播消息失败:', e);
        }
    });
}

function handleChatMessage(data) {
    const room = rooms.get(data.room_id);
    if (!room) {
        console.error(`房间 ${data.room_id} 不存在`);
        return;
    }

    // 构造完整的聊天消息对象
    const chatMessage = {
        type: 'chat_message',
        room_id: data.room_id,
        sender_id: data.sender_id,
        sender_name: data.sender_name || `用户${data.sender_id.substring(0, 4)}`,
        content: data.content,
        timestamp: new Date().toISOString()
    };
    // 保存消息历史（限制最多100条）
    room.chatHistory = [...room.chatHistory, chatMessage].slice(-100);

    // 广播给房间内所有成员（包括发送者自己）
    broadcast(data.room_id, chatMessage);

    console.log(`房间 ${data.room_id} 收到来自 ${chatMessage.sender_name} 的聊天消息: ${data.content}`);
}


//视频共享相关
function handleVideoShareRequest(ws, data) {
    const room = rooms.get(data.room_id);
    if (!room) {
        ws.send(JSON.stringify({
            type: 'error',
            message: '房间不存在'
        }));
        return;
    }

    // 验证请求者是否是房间成员
    if (!room.participants.includes(data.requester_id)) {
        ws.send(JSON.stringify({
            type: 'error',
            message: '非房间成员不能请求视频'
        }));
        return;
    }

    // 检查是否已有进行中的传输
    if (room.activeTransfers.has(data.requester_id)) {
        ws.send(JSON.stringify({
            type: 'error',
            message: '该用户已有进行中的传输'
        }));
        return;
    }

    // 找到房主客户端
    const hostClient = Array.from(wss.clients).find(client =>
        client.readyState === WebSocket.OPEN &&
        client.userId === room.participants[0]
    );

    if (hostClient) {
        // 初始化传输状态
        room.activeTransfers.set(data.requester_id, {
            startTime: Date.now(),
            lastChunkTime: Date.now(),
            fileSize: 0,
            bytesReceived: 0
        });

        // 设置传输超时检查
        const timeoutId = setTimeout(() => {
            if (room.activeTransfers.has(data.requester_id)) {
                room.activeTransfers.delete(data.requester_id);
                console.log(`传输超时已取消: ${data.requester_id}`);
            }
        }, 300000); // 5分钟超时

        hostClient.send(JSON.stringify({
            type: 'video_share_request',
            requester_id: data.requester_id,
            room_id: data.room_id,
            timeout: timeoutId // 注意：实际使用时需要处理timeoutId
        }));
    }
}

function forwardVideoChunk(data) {
    const room = rooms.get(data.room_id);
    if (!room) return;

    const transferInfo = room.activeTransfers.get(data.requester_id);
    if (!transferInfo) {
        console.log('无活跃传输或传输已超时');
        return;
    }

    // 更新传输状态
    transferInfo.lastChunkTime = Date.now();
    transferInfo.bytesReceived += data.data.length;
    transferInfo.fileSize = data.total_size;

    // 检查传输完整性
    if (transferInfo.bytesReceived > transferInfo.fileSize) {
        console.error('接收数据超过文件大小');
        room.activeTransfers.delete(data.requester_id);
        return;
    }

    const targetClient = Array.from(wss.clients).find(client =>
        client.readyState === WebSocket.OPEN &&
        client.userId === data.requester_id
    );

    if (targetClient) {
        try {
            targetClient.send(JSON.stringify(data));
        } catch (e) {
            console.error('转发视频块失败:', e);
            room.activeTransfers.delete(data.requester_id);
        }
    }
}

function forwardVideoTransferComplete(data) {
    const room = rooms.get(data.room_id);
    if (!room) return;

    // 验证传输是否正常完成
    const transferInfo = room.activeTransfers.get(data.requester_id);
    if (!transferInfo) return;

    if (transferInfo.bytesReceived !== transferInfo.fileSize) {
        console.error('传输未完成即收到完成通知');
        return;
    }

    // 清理传输状态
    room.activeTransfers.delete(data.requester_id);

    const targetClient = Array.from(wss.clients).find(client =>
        client.readyState === WebSocket.OPEN &&
        client.userId === data.requester_id
    );

    if (targetClient) {
        targetClient.send(JSON.stringify({
            ...data,
            received_bytes: transferInfo.bytesReceived,
            duration: Date.now() - transferInfo.startTime
        }));
    }

    console.log(`视频传输完成: ${data.requester_id}, 大小: ${transferInfo.fileSize}字节`);
}

function handleSyncRequest(ws, data) {
    const room = rooms.get(data.room_id);
    if (!room) return;

    ws.send(JSON.stringify({
        type: 'sync_playback',
        position: room.playback.position,
        is_playing: room.playback.isPlaying,
    }));
}

function forwardVideoShareResponse(data) {
    const targetClient = Array.from(wss.clients).find(client =>
        client.readyState === WebSocket.OPEN &&
        client.userId === data.requester_id
    );

    if (targetClient) {
        targetClient.send(JSON.stringify(data));
    }
}
