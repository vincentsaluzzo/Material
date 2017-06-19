/*
 * Copyright (C) 2015 - 2017, Daniel Dahan and CosmicMind, Inc. <http://cosmicmind.com>.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *    *    Redistributions of source code must retain the above copyright notice, this
 *        list of conditions and the following disclaimer.
 *
 *    *    Redistributions in binary form must reproduce the above copyright notice,
 *        this list of conditions and the following disclaimer in the documentation
 *        and/or other materials provided with the distribution.
 *
 *    *    Neither the name of CosmicMind nor the names of its
 *        contributors may be used to endorse or promote products derived from
 *        this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import EventKit
import CoreData

@objc(EventsReminderAuthorizationStatus)
public enum EventsReminderAuthorizationStatus: Int {
    case authorized
    case denied
}

@objc(EventsReminderPriority)
public enum EventsReminderPriority: Int {
    case none
    case high = 1
    case medium = 5
    case low = 9
}

@objc(EventsDelegate)
public protocol EventsDelegate {
    /**
     A delegation method that is executed when the reminder authorization 
     status changes.
     - Parameter events: A reference to the Events instance.
     - Parameter status: A reference to the EventReminderAuthorizationStatus.
     */
    @objc
    optional func events(events: Events, status: EventsReminderAuthorizationStatus)
    
    /**
     A delegation method that is fired when changes to the event store occur.
     - Parameter events: A reference to the Events instance.
     */
    @objc
    optional func eventsShouldRefresh(events: Events)
    
    /**
     A delegation method that is executed when events authorization is authorized.
     - Parameter events: A reference to the Events instance.
     */
    @objc
    optional func eventsAuthorizedForReminders(events: Events)
    
    /**
     A delegation method that is executed when events authorization is denied.
     - Parameter events: A reference to the Events instance.
     */
    @objc
    optional func eventsDeniedForReminders(events: Events)
    
    /**
     A delegation method that is executed when a new calendar is created.
     - Parameter events: A reference to the Events instance.
     - Parameter createdCalendar calendar: An optional reference to the calendar created.
     - Parameter error: An optional error if the calendar failed to be created.
     */
    @objc
    optional func events(events: Events, createdCalendar calendar: EKCalendar?, error: Error?)
    
    /**
     A delegation method that is executed when a calendar is updated.
     - Parameter events: A reference to the Events instance.
     - Parameter updatedCalendar calendar: A reference to the updated calendar.
     - Parameter error: An optional error if the calendar failed to be updated.
     */
    @objc
    optional func events(events: Events, updatedCalendar calendar: EKCalendar, error: Error?)
    
    /**
     A delegation method that is executed when a calendar is removed.
     - Parameter events: A reference to the Events instance.
     - Parameter removedCalendar calendar: A reference to the calendar removed.
     - Parameter error: An optional error if the calendar failed to be removed.
     */
    @objc
    optional func events(events: Events, removedCalendar calendar: EKCalendar, error: Error?)
    
    /**
     A delegation method that is executed when a new reminder is created.
     - Parameter events: A reference to the Events instance.
     - Parameter createdReminder reminder: An optional reference to the reminder created.
     - Parameter error: An optional error if the reminder failed to be created.
     */
    @objc
    optional func events(events: Events, createdReminder reminder: EKReminder?, error: Error?)
    
    /**
     A delegation method that is executed when a reminder is updated.
     - Parameter events: A reference to the Events instance.
     - Parameter updatedReminder reminder: A reference to the updated reminder.
     - Parameter error: An optional error if the reminder failed to be updated.
     */
    @objc
    optional func events(events: Events, updatedReminder reminder: EKReminder, error: Error?)
    
    /**
     A delegation method that is executed when a reminder is removed.
     - Parameter events: A reference to the Events instance.
     - Parameter removedReminder reminder: A reference to the removed reminder.
     - Parameter error: An optional error if the reminder failed to be removed.
     */
    @objc
    optional func events(events: Events, removedReminder reminder: EKReminder, error: Error?)
}

@objc(Events)
open class Events: NSObject {
    /// A cache of calendars.
    @objc open fileprivate(set) var cacheForCalendars = [AnyHashable: EKCalendar]()
    
    /// A cache of reminders.
    @objc open fileprivate(set) var cacheForReminders = [AnyHashable: EKReminder]()
    
    /// A boolean indicating whether to commit saves or not.
    fileprivate var isCommitted = true
    
    /// A reference to the eventsStore.
    fileprivate let eventStore = EKEventStore()
    
    /// The current EventsReminderAuthorizationStatus.
    @objc open var authorizationStatusForReminders: EventsReminderAuthorizationStatus {
        return .authorized == EKEventStore.authorizationStatus(for: .reminder) ? .authorized : .denied
    }
    
    /// A reference to an EventsDelegate.
    @objc open weak var delegate: EventsDelegate?
    
    /// Denitializer.
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /**
     Requests authorization for reminders.
     - Parameter completion: An optional completion callback.
     */
    @objc open func requestAuthorizationForReminders(completion: ((EventsReminderAuthorizationStatus) -> Void)? = nil) {
        eventStore.requestAccess(to: .reminder) { [weak self, completion = completion] (isAuthorized, _) in
            DispatchQueue.main.async { [weak self, completion = completion] in
                guard let s = self else {
                    return
                }
                
                guard isAuthorized else {
                    completion?(.denied)
                    s.delegate?.events?(events: s, status: .denied)
                    s.delegate?.eventsDeniedForReminders?(events: s)
                    return
                }
                
                s.prepareNotification()
                
                completion?(.authorized)
                s.delegate?.events?(events: s, status: .authorized)
                s.delegate?.eventsAuthorizedForReminders?(events: s)
            }
        }
    }
}

extension Events {
    /// Prepares the notification handlers.
    fileprivate func prepareNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleEventStoreChange(_:)), name: NSNotification.Name.EKEventStoreChanged, object: eventStore)
    }
}

extension Events {
    /**
     Handler for event store changes.
     - Parameter _ notification: A Notification.
     */
    @objc
    fileprivate func handleEventStoreChange(_ notification: Notification) {
        delegate?.eventsShouldRefresh?(events: self)
    }
}

extension Events {
    /// Begins a storage transaction.
    @objc open func begin() {
        isCommitted = false
    }
    
    /// Resets the storage transaction state.
    @objc open func reset() {
        isCommitted = true
    }
    
    /**
     Commits the storage transaction.
     - Parameter completion: A completion call back.
     */
    @objc open func commit(_ completion: ((Bool, Error?) -> Void)) {
        reset()
        
        var success = false
        var error: Error?
        
        do {
            try eventStore.commit()
            success = true
        } catch let e {
            error = e
        }
        
        completion(success, error)
    }
}

extension Events {
    /**
     Creates a predicate for the events Array of calendars.
     - Parameter in calendars: An optional Array of EKCalendars.
     */
    @objc open func predicateForReminders(in calendars: [EKCalendar]) -> NSPredicate {
        return eventStore.predicateForReminders(in: calendars)
    }
    
    /**
     Creates a predicate with a given start and end date for
     incomplete reminders. Providing a calendars Array narrows
     the search.
     - Parameter starting: A Date.
     - Parameter ending: A Date.
     - Parameter calendars: An optional Array of [EKCalendar].
     */
    @objc open func predicateForIncompleteReminders(starting: Date, ending: Date, calendars: [EKCalendar]? = nil) -> NSPredicate {
        return eventStore.predicateForIncompleteReminders(withDueDateStarting: starting, ending: ending, calendars: calendars)
    }
    
    /**
     Creates a predicate with a given start and end date for
     completed reminders. Providing a calendars Array narrows 
     the search.
     - Parameter starting: A Date.
     - Parameter ending: A Date.
     - Parameter calendars: An optional Array of [EKCalendar].
     */
    @objc open func predicateForCompletedReminders(starting: Date, ending: Date, calendars: [EKCalendar]? = nil) -> NSPredicate {
        return eventStore.predicateForCompletedReminders(withCompletionDateStarting: starting, ending: ending, calendars: calendars)
    }
}

extension Events {
    /**
     Fetches all calendars for a given reminder.
     - Parameter completion: A completion call back
     */
    @objc open func fetchCalendarsForReminders(_ completion: @escaping ([EKCalendar]) -> Void) {
        DispatchQueue.global(qos: .default).async { [weak self, completion = completion] in
            guard let s = self else {
                return
            }
            
            let calendars = s.eventStore.calendars(for: .reminder).sorted(by: { (a, b) -> Bool in
                return a.title < b.title
            })
            
            for calendar in calendars {
                s.cacheForCalendars[calendar.calendarIdentifier] = calendar
            }
            
            DispatchQueue.main.async { [calendars = calendars, completion = completion] in
                completion(calendars)
                
            }
        }
    }
    
    /**
     Fetches all reminders matching a given predicate.
     - Parameter predicate: A NSPredicate.
     - Parameter completion: A completion call back.
     - Returns: A fetch events request identifier.
     */
    @objc @discardableResult
    open func fetchReminders(matching predicate: NSPredicate, completion: @escaping ([EKReminder]) -> Void) -> Any {
        return eventStore.fetchReminders(matching: predicate, completion: { [weak self, completion = completion] (reminders) in
            guard let s = self else {
                return
            }
            
            let r = reminders ?? []
            
            for reminder in r {
                s.cacheForReminders[reminder.calendarItemIdentifier] = reminder
            }
            
            DispatchQueue.main.async { [completion = completion] in
                completion(r)
            }
        })
    }
    
    /**
     Fetch all the events in a given Array of calendars.
     - Parameter in calendars: An Array of EKCalendars.
     - Parameter completion: A completion call back.
     - Returns: A fetch events request identifier.
     */
    @objc @discardableResult
    open func fetchReminders(in calendars: [EKCalendar], completion: @escaping ([EKReminder]) -> Void) -> Any {
        return fetchReminders(matching: predicateForReminders(in: calendars), completion: completion)
    }
    
    /**
     Fetch all the events in a given Array of calendars that
     are incomplete, given a start and end date.
     - Parameter starting: A Date.
     - Parameter ending: A Date.
     - Parameter calendars: An Array of EKCalendars.
     - Parameter completion: A completion call back.
     - Returns: A fetch events request identifier.
     */
    @objc @discardableResult
    open func fetchIncompleteReminders(starting: Date, ending: Date, calendars: [EKCalendar]? = nil, completion: @escaping ([EKReminder]) -> Void) -> Any {
        return fetchReminders(matching: predicateForIncompleteReminders(starting: starting, ending: ending, calendars: calendars), completion: completion)
    }
    
    /**
     Fetch all the events in a given Array of calendars that
     are completed, given a start and end date.
     - Parameter starting: A Date.
     - Parameter ending: A Date.
     - Parameter calendars: An Array of EKCalendars.
     - Parameter completion: A completion call back.
     - Returns: A fetch events request identifier.
     */
    @objc @discardableResult
    open func fetchCompletedReminders(starting: Date, ending: Date, calendars: [EKCalendar]? = nil, completion: @escaping ([EKReminder]) -> Void) -> Any {
        return fetchReminders(matching: predicateForCompletedReminders(starting: starting, ending: ending, calendars: calendars), completion: completion)
    }
    
    /**
     Cancels an active events request.
     - Parameter _ identifier: An identifier.
     */
    @objc open func cancelFetchRequest(_ identifier: Any) {
        eventStore.cancelFetchRequest(identifier)
    }
}

extension Events {
    /**
     Creates a new reminder calendar.
     - Parameter calendar title: the name of the list.
     - Parameter completion: An optional completion call back.
     */
    @objc open func createCalendarForReminders(title: String, completion: ((EKCalendar?, Error?) -> Void)? = nil) {
        DispatchQueue.global(qos: .default).async { [weak self, completion = completion] in
            guard let s = self else {
                return
            }
            
            let calendar = EKCalendar(for: .reminder, eventStore: s.eventStore)
            calendar.title = title
            
            calendar.source = s.eventStore.defaultCalendarForNewReminders()?.source
                    
            var success = false
            var error: Error?
            
            do {
                try s.eventStore.saveCalendar(calendar, commit: s.isCommitted)
                success = true
                
                s.cacheForCalendars[calendar.calendarIdentifier] = calendar
            } catch let e {
                error = e
            }
            
            DispatchQueue.main.async { [weak self, calendar = calendar, error = error, completion = completion] in
                guard let s = self else {
                    return
                }
                
                completion?(success ? calendar : nil, error)
                s.delegate?.events?(events: s, createdCalendar: success ? calendar : nil, error: error)
            }
        }
    }
    
    /**
     Updates a given calendar.
     - Parameter calendar: An EKCalendar.
     - Parameter completion: An optional completion call back.
     */
    @objc open func update(calendar: EKCalendar, completion: ((Bool, Error?) -> Void)? = nil) {
        DispatchQueue.global(qos: .default).async { [weak self, calendar = calendar, completion = completion] in
            guard let s = self else {
                return
            }
            
            var success = false
            var error: Error?
            
            do {
                try s.eventStore.saveCalendar(calendar, commit: s.isCommitted)
                success = true
                
                s.cacheForCalendars[calendar.calendarIdentifier] = calendar
            } catch let e {
                error = e
            }
            
            DispatchQueue.main.async { [weak self, calendar = calendar, error = error, completion = completion] in
                guard let s = self else {
                    return
                }
                
                completion?(success, error)
                s.delegate?.events?(events: s, updatedCalendar: calendar, error: error)
            }
        }
    }
    
    /**
     Removes an existing calendar,
     - Parameter calendar identifier: The EKCalendar identifier String.
     - Parameter completion: An optional completion call back.
     */
    @objc open func removeCalendar(identifier: String, completion: ((Bool, Error?) -> Void)? = nil) {
        DispatchQueue.global(qos: .default).async { [weak self, completion = completion] in
            guard let s = self else {
                return
            }
            
            var success = false
            var error: Error?
            
            guard let calendar = s.eventStore.calendar(withIdentifier: identifier) else {
                var userInfo = [String: Any]()
                userInfo[NSLocalizedDescriptionKey] = "[Material Error: Cannot remove calendar with identifier \(identifier).]"
                userInfo[NSLocalizedFailureReasonErrorKey] = "[Material Error: Cannot remove calendar with identifier \(identifier).]"
                error = NSError(domain: "com.cosmicmind.material.events", code: 0001, userInfo: userInfo)
                
                completion?(success, error)
                return
            }
            
            do {
                let calendarIdentifier = calendar.calendarIdentifier
                
                try s.eventStore.removeCalendar(calendar, commit: s.isCommitted)
                success = true
                
                s.cacheForCalendars[calendarIdentifier] = nil
            } catch let e {
                error = e
            }
            
            DispatchQueue.main.async { [weak self, calendar = calendar, error = error, completion = completion] in
                guard let s = self else {
                    return
                }
                
                completion?(success, error)
                s.delegate?.events?(events: s, removedCalendar: calendar, error: error)
            }
        }
    }
}

extension Events {    
    /**
     Adds a new reminder to an optionally existing list.
     if the list does not exist it will be added to the default events list.
     - Parameter title: A String.
     - Parameter calendar: An EKCalendar.
     - Parameter startDateComponents: An optional DateComponents.
     - Parameter dueDateComponents: An optional DateComponents.
     - Parameter priority: An optional EventsReminderPriority.
     - Parameter completion: An optional completion call back.
     */
    open func createReminder(title: String, calendar: EKCalendar, startDateComponents: DateComponents? = nil, dueDateComponents: DateComponents? = nil, priority: EventsReminderPriority? = .none, notes: String?, completion: ((EKReminder?, Error?) -> Void)? = nil) {
        DispatchQueue.global(qos: .default).async { [weak self, calendar = calendar, completion = completion] in
            guard let s = self else {
                return
            }
            
            let reminder = EKReminder(eventStore: s.eventStore)
            reminder.title = title
            reminder.calendar = calendar
            reminder.startDateComponents = startDateComponents
            reminder.dueDateComponents = dueDateComponents
            reminder.priority = priority?.rawValue ?? EventsReminderPriority.none.rawValue
            reminder.notes = notes
            
            var success = false
            var error: Error?
            
            do {
                try s.eventStore.save(reminder, commit: s.isCommitted)
                success = true
                
                s.cacheForReminders[reminder.calendarItemIdentifier] = reminder
            } catch let e {
                error = e
            }
            
            DispatchQueue.main.async { [weak self, reminder = reminder, error = error, completion = completion] in
                guard let s = self else {
                    return
                }
                
                completion?(success ? reminder : nil, error)
                s.delegate?.events?(events: s, createdReminder: success ? reminder : nil, error: error)
            }
        }
    }

    /**
     Updates a given reminder.
     - Parameter reminder: An EKReminder. 
     - Parameter completion: An optional completion call back.
     */
    @objc open func update(reminder: EKReminder, completion: ((Bool, Error?) -> Void)? = nil) {
        DispatchQueue.global(qos: .default).async { [weak self, reminder = reminder, completion = completion] in
            guard let s = self else {
                return
            }
            
            var success = false
            var error: Error?
            
            do {
                try s.eventStore.save(reminder, commit: s.isCommitted)
                success = true
                
                s.cacheForReminders[reminder.calendarItemIdentifier] = reminder
            } catch let e {
                error = e
            }
            
            DispatchQueue.main.async { [weak self, reminder = reminder, error = error, completion = completion] in
                guard let s = self else {
                    return
                }
                
                completion?(success, error)
                s.delegate?.events?(events: s, updatedReminder: reminder, error: error)
            }
        }
    }
    
    /**
     Removes an existing reminder,
     - Parameter reminder identifier: The EKReminders identifier String.
     - Parameter completion: An optional completion call back.
     */
    @objc open func removeReminder(identifier: String, completion: ((Bool, Error?) -> Void)? = nil) {
        DispatchQueue.global(qos: .default).async { [weak self, completion = completion] in
            guard let s = self else {
                return
            }
            
            var success = false
            var error: Error?
            
            guard let reminder = s.eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
                var userInfo = [String: Any]()
                userInfo[NSLocalizedDescriptionKey] = "[Material Error: Cannot remove reminder with identifier \(identifier).]"
                userInfo[NSLocalizedFailureReasonErrorKey] = "[Material Error: Cannot remove reminder with identifier \(identifier).]"
                error = NSError(domain: "com.cosmicmind.material.events", code: 0002, userInfo: userInfo)
                
                completion?(success, error)
                return
            }
            
            do {
                let calendarItemIdentifier = reminder.calendarItemIdentifier
                
                try s.eventStore.remove(reminder, commit: s.isCommitted)
                success = true
                
                s.cacheForReminders[calendarItemIdentifier] = nil
            } catch let e {
                error = e
            }
            
            DispatchQueue.main.async { [weak self, reminder = reminder, error = error, completion = completion] in
                guard let s = self else {
                    return
                }
                
                completion?(success, error)
                s.delegate?.events?(events: s, removedReminder: reminder, error: error)
            }
        }
    }
}

extension Events {
    /**
     Creates an alarm using the current time plus a given timeInterval.
     - Parameter timeIntervalSinceNow: A TimeInterval.
     - Returns: An EKAlarm.
     */
    @objc open func createAlarm(timeIntervalSinceNow: TimeInterval) -> EKAlarm {
        return EKAlarm(absoluteDate: Date(timeIntervalSinceNow: timeIntervalSinceNow))
    }
    
    /**
     Creates an alarm using given date components.
     - Parameter day: An optional Int.
     - Parameter month: An optional Int.
     - Parameter year: An optional Int.
     - Parameter hour: An optional Int.
     - Parameter minute: An optional Int.
     - Parameter second: An optional Int.
     - Returns: An optional EKAlarm.
     */
    open func createAlarm(day: Int? = nil, month: Int? = nil, year: Int? = nil, hour: Int? = nil, minute: Int? = nil, second: Int? = nil) -> EKAlarm {
        var dateComponents = DateComponents()
        
        dateComponents.calendar = Calendar.current
        dateComponents.day = day
        dateComponents.month = month
        dateComponents.year = year
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = second
        
        return EKAlarm(absoluteDate: dateComponents.date!)
    }
    
    /**
     Creates an alarm using a relative offset from the start date.
     - Parameter relativeOffset offset: A TimeInterval.
     - Returns: An EKAlarm.
     */
    @objc open func createAlarm(relativeOffset offset: TimeInterval) -> EKAlarm {
        return EKAlarm(relativeOffset: offset)
    }
}
