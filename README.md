Testing

user = User.find_by_username_lower("communiteq")
ei = user.custom_fields[:engagement_info]
ei[:level] = 0
user.custom_fields[:engagement_info] = ei
user.save_custom_fields

ei[:level] = 1
user.custom_fields[:engagement_info] = ei
user.save_custom_fields

ei[:level] = 2
user.custom_fields[:engagement_info] = ei
user.save_custom_fields

ei[:level] = 3
user.custom_fields[:engagement_info] = ei
user.save_custom_fields

ei[:level] = 4
user.custom_fields[:engagement_info] = ei
user.save_custom_fields

ei[:level] = 5
score = 100
ei[:emoji_from] = score
ei[:emoji_to] = score + 10
ei[:emoji] = 'fireworks'
user.custom_fields[:engagement_info] = ei
user.save_custom_fields

ei[:level] = 6
user.custom_fields[:engagement_info] = ei
user.save_custom_fields

ei[:level] = 7
user.custom_fields[:engagement_info] = ei
user.save_custom_fields