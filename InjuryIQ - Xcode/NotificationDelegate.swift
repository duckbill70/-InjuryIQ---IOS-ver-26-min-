//
//  NotificationDelegate.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 02/02/2026.
//

import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
		completionHandler([.banner, .sound, .list])
    }
}

public func postImmediateNotification(with text: String) {
	let content = UNMutableNotificationContent()
	content.title = "Notification"
	content.body = text
	content.sound = .default

	let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
	let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

	UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
}
